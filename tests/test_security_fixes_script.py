"""
Tests for scripts/test/security_fixes.sh

A deployment test script is only worth having if it still fails on a
deployment that has the problem. These stand up a mock deployment in each
configuration and run the real script against it, so the script cannot quietly
rot into one that passes on anything.
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
SCRIPT = ROOT / 'scripts/test/security_fixes.sh'
MOCK = ROOT / 'tests/fixtures/mock_deployment.py'

VULNERABLE_PORT = 8971
FIXED_PORT = 8972


class MockDeployment:
    """
    Runs the mock deployment in one configuration for the duration of a block
    """

    def __init__(self, mode, port):
        self.mode = mode
        self.port = port
        self.process = None

    def __enter__(self):
        self.process = subprocess.Popen(
            [sys.executable, str(MOCK), self.mode, str(self.port)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        self._wait_until_listening()
        return self

    def __exit__(self, *exception):
        self.process.terminate()
        self.process.wait(timeout=10)

    def _wait_until_listening(self):
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            try:
                urllib.request.urlopen(
                    f'http://127.0.0.1:{self.port}/', timeout=1
                ).read()
                return
            except urllib.error.HTTPError:
                return
            except OSError:
                time.sleep(0.1)
        raise AssertionError(
            f'the mock deployment did not start on port {self.port}'
        )

    def run_script(self, section='all', session_cookie=None):
        environment = {'PATH': '/usr/bin:/bin:/usr/local/bin'}
        if session_cookie:
            environment['SESSION_COOKIE'] = session_cookie

        completed = subprocess.run(
            ['bash', str(SCRIPT), f'http://127.0.0.1:{self.port}', section],
            capture_output=True, text=True, env=environment, timeout=180,
        )
        # Strip the colour codes so assertions read against plain text
        output = re.sub(r'\x1b\[[0-9;]*m', '', completed.stdout)
        return completed.returncode, output


class TestTheScriptIsRunnable(unittest.TestCase):

    def test_the_script_is_executable(self):
        self.assertTrue(SCRIPT.exists(), f'{SCRIPT} is missing')
        self.assertTrue(
            SCRIPT.stat().st_mode & 0o111,
            f'{SCRIPT} is not executable'
        )

    def test_the_script_parses(self):
        completed = subprocess.run(
            ['bash', '-n', str(SCRIPT)], capture_output=True, text=True
        )
        self.assertEqual(
            completed.returncode, 0,
            f'bash -n rejected the script: {completed.stderr}'
        )

    def test_an_unknown_section_is_refused(self):
        completed = subprocess.run(
            ['bash', str(SCRIPT), 'http://127.0.0.1:1', 'nonsense'],
            capture_output=True, text=True, timeout=60,
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn('Unknown section', completed.stdout)


class TestItFailsOnAVulnerableDeployment(unittest.TestCase):
    """
    The half that matters. A script that only passes proves nothing.
    """

    def test_it_exits_non_zero(self):
        with MockDeployment('vulnerable', VULNERABLE_PORT) as deployment:
            code, output = deployment.run_script()
        self.assertNotEqual(
            code, 0,
            'the script passed against a deployment serving the wildcard '
            'policy and an unauthenticated noticeboard'
        )

    def test_it_names_the_wildcard_policy(self):
        with MockDeployment('vulnerable', VULNERABLE_PORT) as deployment:
            _, output = deployment.run_script('csp')
        self.assertIn('default-src allows every origin', output)

    def test_it_names_every_readable_notice_route(self):
        with MockDeployment('vulnerable', VULNERABLE_PORT) as deployment:
            _, output = deployment.run_script('noticeboard')

        for route in (
            '/api/noticeboard/new/',
            '/api/noticeboard/old/',
            '/api/noticeboard/filter/',
            '/api/noticeboard/institute_notices/',
        ):
            self.assertIn(
                f'FAIL {route} -> HTTP 200', output,
                f'the script did not report {route} as readable'
            )


class TestItPassesOnAFixedDeployment(unittest.TestCase):

    def test_the_policy_section_passes(self):
        with MockDeployment('fixed', FIXED_PORT) as deployment:
            code, output = deployment.run_script('csp')
        self.assertEqual(code, 0, output)
        self.assertIn('no * source in the directives that matter', output)

    def test_the_noticeboard_section_passes_with_a_session(self):
        with MockDeployment('fixed', FIXED_PORT) as deployment:
            code, output = deployment.run_script(
                'noticeboard', session_cookie='sessionid=test'
            )
        self.assertEqual(code, 0, output)
        self.assertIn('authenticated GET /api/noticeboard/new/ -> HTTP 200',
                      output)

    def test_an_over_tight_fix_is_reported(self):
        """
        Locking out logged-in people is a failure too, not a success
        """

        with MockDeployment('fixed', FIXED_PORT) as deployment:
            # No session cookie, so the mock answers 401 to the authenticated
            # check as well. The script must warn rather than claim a pass.
            _, output = deployment.run_script('noticeboard')

        self.assertIn('SESSION_COOKIE not set', output)
        self.assertIn('WARN', output)


class TestARunThatCheckedNothingIsNotAPass(unittest.TestCase):
    """
    The script warns that warnings are not passes, and then reported success
    on a run where every check was skipped. This is that regression.
    """

    def test_a_section_that_skips_everything_exits_non_zero(self):
        # The pillow section reads a version out of a container. Where there is
        # no reachable container it warns and asserts nothing at all.
        with MockDeployment('fixed', FIXED_PORT) as deployment:
            code, output = deployment.run_script('pillow')

        self.assertIn('Total Tests: 0', output)
        self.assertNotIn('ALL TESTS PASSED', output)
        self.assertIn('NO CHECKS RAN', output)
        self.assertNotEqual(
            code, 0,
            'a run that verified nothing exited 0, so a pipeline would read it '
            'as a pass'
        )


if __name__ == '__main__':
    unittest.main()
