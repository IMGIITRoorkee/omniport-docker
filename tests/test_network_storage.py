"""
Tests for network-storage/omniport-network-storage.sh, run against stub system commands
"""

import os
import pathlib
import subprocess
import tempfile
import textwrap
import time
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRIPT = ROOT / 'network-storage' / 'omniport-network-storage.sh'

# Each stub records its arguments and reads flag files in $STUB to decide how
# the simulated host behaves.
STUBS = {
    'logger': 'echo "$*" >> "$STUB/log"',
    'journalctl': 'exit 0',
    'dmesg': 'exit 0',
    'systemctl': '''
        echo "systemctl $*" >> "$STUB/calls"
        if [ "$1" = restart ] && [ -e "$STUB/remount-ok" ]; then
            echo "999 28 0:500 / $NS rw shared:1 - fuse.s3fs s3fs rw" >> "$MOUNTINFO"
        fi
    ''',
    'docker-compose': '''
        echo "docker-compose $*" >> "$STUB/calls"
        case "$1" in
            exec) [ -e "$STUB/containers-ok" ] ;;
            restart) [ -e "$STUB/restart-fixes" ] && touch "$STUB/containers-ok"; exit 0 ;;
        esac
    ''',
    'umount': '''
        echo "umount $*" >> "$STUB/calls"
        [ -e "$STUB/umount-stuck" ] && exit 0
        n=$(grep -n " $NS " "$MOUNTINFO" | tail -1 | cut -d: -f1)
        [ -n "$n" ] && sed -i.bak "${n}d" "$MOUNTINFO"
        exit 0
    ''',
}


def s3fs_line(ns, conn, parent=28):
    return f'{conn} {parent} 0:{conn} / {ns} rw,nosuid shared:{conn} - fuse.s3fs s3fs rw\n'


class NetworkStorageTestCase(unittest.TestCase):
    """
    Base class that builds a throwaway host: a mountpoint, a mountinfo file,
    FUSE connection directories and stubs on PATH
    """

    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp())
        self.stub = self.tmp / 'stub'
        self.bin = self.tmp / 'bin'
        self.ns = self.tmp / 'network_storage'
        self.mountinfo = self.tmp / 'mountinfo'
        self.connections = self.tmp / 'connections'
        for directory in (self.stub, self.bin, self.ns / 'public', self.connections):
            directory.mkdir(parents=True)
        (self.stub / 'calls').touch()
        self.mountinfo.write_text(
            '312 28 0:51 / /var/lib/lxcfs rw shared:182 - fuse.lxcfs lxcfs rw\n'
        )
        for name, body in STUBS.items():
            self.write_stub(self.bin, name, body)
        self.env = {
            **os.environ,
            'PATH': f'{self.bin}:{os.environ["PATH"]}',
            'STUB': str(self.stub),
            'NS': str(self.ns),
            'MOUNTINFO': str(self.mountinfo),
            'FUSE_CONNECTIONS': str(self.connections),
            'STATE_DIR': str(self.tmp / 'state'),
            'LOG_DIR': str(self.tmp / 'log'),
            'COMPOSE_DIR': str(self.tmp),
            'PROBE_TIMEOUT': '2',
            'PROBE_INTERVAL': '0',
        }

    @staticmethod
    def write_stub(directory, name, body):
        path = directory / name
        path.write_text('#!/bin/bash\n' + textwrap.dedent(body))
        path.chmod(0o755)

    def flag(self, name):
        (self.stub / name).touch()

    def mount(self, conn):
        with open(self.mountinfo, 'a') as mountinfo:
            mountinfo.write(s3fs_line(self.ns, conn))

    def run_script(self, command):
        return subprocess.run(
            ['bash', str(SCRIPT), command],
            env=self.env, capture_output=True, text=True, timeout=60,
        )

    def calls(self):
        return (self.stub / 'calls').read_text()

    def restarted_containers(self):
        return 'docker-compose restart' in self.calls()

    def restarted_unit(self):
        return 'systemctl restart' in self.calls()


class WatchdogTests(NetworkStorageTestCase):
    """
    The watchdog repairs only what is broken, and never restarts the
    containers onto a directory that is not the live mount
    """

    def test_healthy_storage_is_left_alone(self):
        self.mount(346)
        self.flag('containers-ok')
        result = self.run_script('watchdog')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.restarted_unit())
        self.assertFalse(self.restarted_containers())

    def test_stale_containers_are_restarted_without_remounting(self):
        self.mount(346)
        self.flag('restart-fixes')
        result = self.run_script('watchdog')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.restarted_unit())
        self.assertTrue(self.restarted_containers())

    def test_bare_placeholder_directory_counts_as_dead(self):
        # The mountpoint lists fine because the repository tracks placeholder
        # directories in it; only the mount table shows nothing is mounted.
        self.flag('remount-ok')
        self.flag('restart-fixes')
        result = self.run_script('watchdog')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.restarted_unit())
        self.assertTrue(self.restarted_containers())
        self.assertTrue(list((self.tmp / 'log').glob('forensics-*.log')))

    def test_failed_remount_leaves_the_containers_alone(self):
        result = self.run_script('watchdog')
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.restarted_unit())
        self.assertFalse(self.restarted_containers())
        self.assertIn('remount', (self.stub / 'log').read_text())

    def test_hung_listing_counts_as_dead(self):
        self.mount(346)
        self.write_stub(self.bin, 'ls', 'exec sleep 30')
        self.env['PROBE_TIMEOUT'] = '1'
        started = time.monotonic()
        result = self.run_script('watchdog')
        self.assertLess(time.monotonic() - started, 50)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.restarted_unit())

    def test_repeat_failure_within_cooldown_only_alerts(self):
        state = self.tmp / 'state'
        state.mkdir()
        (state / 'last-repair').write_text(str(int(time.time())))
        result = self.run_script('watchdog')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.restarted_unit())
        self.assertFalse(self.restarted_containers())
        self.assertIn('not repairing again', (self.stub / 'log').read_text())


class ReleaseTests(NetworkStorageTestCase):
    """
    Release clears a whole stack of s3fs mounts and touches no other FUSE mount
    """

    def test_release_aborts_and_unmounts_every_stacked_mount(self):
        for conn in ('51', '346', '348'):
            (self.connections / conn).mkdir()
        self.mount(348)
        self.mount(346)
        result = self.run_script('release')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.connections / '346' / 'abort').exists())
        self.assertTrue((self.connections / '348' / 'abort').exists())
        self.assertFalse((self.connections / '51' / 'abort').exists())
        self.assertEqual(self.calls().count('umount'), 2)
        self.assertNotIn('fuse.s3fs', self.mountinfo.read_text())

    def test_release_gives_up_on_a_stack_that_will_not_unmount(self):
        self.mount(346)
        self.flag('umount-stuck')
        result = self.run_script('release')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('could not release', (self.stub / 'log').read_text())

    def test_await_fails_when_nothing_is_mounted(self):
        result = self.run_script('await')
        self.assertNotEqual(result.returncode, 0)

    def test_await_succeeds_on_a_live_mount(self):
        self.mount(346)
        result = self.run_script('await')
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
