"""
Tests for scripts/test/pr_verification.sh

The script is only worth running on staging if it still reports a deployment
that has the problem. These stand up a mock deployment in a fixed and a
vulnerable configuration and run the real script against both, asserting that
each per-PR check reports the defect it was written for.
"""

import pathlib
import re
import subprocess
import sys
import time
import unittest
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRIPT = ROOT / 'scripts/test/pr_verification.sh'
MOCK = ROOT / 'tests/fixtures/mock_pr_deployment.py'

FIXED_PORT = 8931
VULNERABLE_PORT = 8932

SECTIONS = (
    'groups-8', 'noticeboard-26', 'people-search-13', 'lost-and-found-7',
    'registration-2', 'gif-3', 'pseudoc-1', 'backend-227', 'formula-one-19',
    'backend-228', 'lectures-25', 'filemanager-80', 'maintainer-site-15',
    'backend-226',
)


class MockDeployment:
    def __init__(self, mode, port):
        self.mode = mode
        self.port = port
        self.process = None

    def __enter__(self):
        self.process = subprocess.Popen(
            [sys.executable, str(MOCK), self.mode, str(self.port)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            try:
                urllib.request.urlopen(
                    f'http://127.0.0.1:{self.port}/', timeout=1
                ).read()
                return self
            except urllib.error.HTTPError:
                return self
            except OSError:
                time.sleep(0.1)
        raise AssertionError(f'mock did not start on port {self.port}')

    def __exit__(self, *exception):
        self.process.terminate()
        self.process.wait(timeout=10)

    def run(self, section='all', session_cookie='sessionid=test'):
        environment = {'PATH': '/usr/bin:/bin:/usr/local/bin'}
        if session_cookie:
            environment['SESSION_COOKIE'] = session_cookie
        completed = subprocess.run(
            ['bash', str(SCRIPT), f'http://127.0.0.1:{self.port}', section],
            capture_output=True, text=True, env=environment, timeout=600,
        )
        return completed.returncode, re.sub(r'\x1b\[[0-9;]*m', '', completed.stdout)


class TestTheScriptIsRunnable(unittest.TestCase):

    def test_it_is_executable(self):
        self.assertTrue(SCRIPT.exists())
        self.assertTrue(SCRIPT.stat().st_mode & 0o111, 'not executable')

    def test_it_parses(self):
        completed = subprocess.run(['bash', '-n', str(SCRIPT)],
                                   capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)

    def test_every_section_is_dispatchable(self):
        """
        A section named in the help text but not wired up would be silent
        """

        completed = subprocess.run(
            ['bash', str(SCRIPT), 'http://127.0.0.1:1', 'list'],
            capture_output=True, text=True, timeout=60,
        )
        listed = re.sub(r'\x1b\[[0-9;]*m', '', completed.stdout)
        for name in SECTIONS:
            self.assertIn(name, listed, f'{name} is not listed')
            self.assertIn(
                f'section_{name.replace("-", "_")}', SCRIPT.read_text(),
                f'{name} is listed but has no function'
            )

    def test_an_unknown_section_is_refused(self):
        completed = subprocess.run(
            ['bash', str(SCRIPT), 'http://127.0.0.1:1', 'nonsense'],
            capture_output=True, text=True, timeout=60,
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn('Unknown section', completed.stdout)


class TestItRunsWithoutShellErrors(unittest.TestCase):
    """
    `bash -n` cannot see unbound variables or bad arithmetic inside a function,
    so every section is executed at least once.
    """

    def test_no_section_produces_a_shell_error(self):
        with MockDeployment('fixed', FIXED_PORT) as deployment:
            _, output = deployment.run()

        for marker in ('command not found', 'unary operator expected',
                       'syntax error', 'integer expression expected',
                       'unbound variable'):
            self.assertNotIn(marker, output, f'shell error: {marker}')

    def test_every_section_actually_ran(self):
        with MockDeployment('fixed', FIXED_PORT) as deployment:
            _, output = deployment.run()

        for name in SECTIONS:
            pr = name.rsplit('-', 1)
            self.assertIn(
                f'{pr[0]}#{pr[1]}', output,
                f'the header for {name} never appeared, so it did not run'
            )


class TestItReportsAVulnerableDeployment(unittest.TestCase):
    """
    Each assertion here is a specific finding the wave is meant to close.
    """

    @classmethod
    def setUpClass(cls):
        with MockDeployment('vulnerable', VULNERABLE_PORT) as deployment:
            cls.code, cls.output = deployment.run()

    def test_it_exits_non_zero(self):
        self.assertNotEqual(self.code, 0)

    def test_it_reports_the_open_faculty_write_routes(self):
        for method in ('POST', 'PUT', 'PATCH', 'DELETE'):
            self.assertIn(f'FAIL {method} on the faculty collection',
                          self.output)

    def test_it_reports_the_leaked_visibility_configuration(self):
        self.assertIn('still carries the visibility arrays', self.output)

    def test_it_reports_the_live_getitem_route(self):
        self.assertIn('FAIL lostitem getItem', self.output)

    def test_it_reports_contact_details_behind_a_false_flag(self):
        self.assertIn('opted-out row(s) still carry contact details',
                      self.output)

    def test_it_reports_the_dropped_options_actions(self):
        """
        The regression that white-screens the public Team and Alumni pages
        """

        self.assertIn('has no actions key', self.output)

    def test_it_reports_the_anonymous_user_mutation(self):
        self.assertIn('update_user', self.output)


class TestItPassesTheClosedChecksWhenFixed(unittest.TestCase):

    def test_the_read_only_sections_pass(self):
        """
        Sections whose checks the mock models faithfully must come out clean
        """

        with MockDeployment('fixed', FIXED_PORT) as deployment:
            for section in ('gif-3', 'formula-one-19', 'lost-and-found-7'):
                code, output = deployment.run(section)
                self.assertEqual(
                    code, 0, f'{section} failed on a fixed deployment:\n{output}'
                )

    def test_missing_session_is_a_warning_not_a_pass(self):
        with MockDeployment('fixed', FIXED_PORT) as deployment:
            _, output = deployment.run('groups-8', session_cookie=None)

        self.assertIn('WARN', output)
        self.assertIn('SESSION_COOKIE', output)


if __name__ == '__main__':
    unittest.main()
