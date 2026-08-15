"""
Tests for the security response headers NGINX adds
"""

import pathlib
import re
import unittest

INCLUDES = pathlib.Path(__file__).resolve().parent.parent / 'nginx/conf.d/includes'

# A source list of `*` in any of these lets an injected tag reach any origin it
# likes, which is what the wildcard policy allowed.
DIRECTIVES_THAT_MUST_NOT_BE_WILDCARD = (
    'default-src',
    'script-src',
    'connect-src',
    'frame-src',
    'object-src',
    'base-uri',
    'form-action',
)

# Directives that must be present and locked down, with the value required.
DIRECTIVES_THAT_MUST_BE_SET = {
    'object-src': "'none'",
    'base-uri': "'self'",
    'form-action': "'self'",
    'frame-ancestors': "'self'",
}

HEADER_PATTERN = re.compile(
    r'^\s*add_header\s+(?P<name>[\w-]+)\s+"(?P<value>[^"]*)"', re.MULTILINE
)


def security_conf_files():
    """
    Every include fragment that adds response headers
    """

    return sorted(INCLUDES.glob('security*.conf'))


def parse_headers(path):
    """
    Return a mapping of header name to value for one include fragment
    """

    text = path.read_text()
    return {
        match.group('name'): match.group('value')
        for match in HEADER_PATTERN.finditer(text)
    }


def parse_csp(value):
    """
    Return a mapping of CSP directive name to its list of sources
    """

    directives = {}
    for directive in value.split(';'):
        parts = directive.split()
        if parts:
            directives[parts[0]] = parts[1:]
    return directives


class TestContentSecurityPolicy(unittest.TestCase):
    """
    The policy must name the origins it allows rather than allowing all of them
    """

    def test_a_policy_is_present(self):
        """
        At least one fragment must carry a Content-Security-Policy
        """

        found = [
            path for path in security_conf_files()
            if 'Content-Security-Policy' in parse_headers(path)
        ]
        self.assertTrue(
            found,
            'no include fragment adds a Content-Security-Policy header'
        )

    def test_no_directive_allows_every_origin(self):
        """
        `*` must not appear as a source in the directives that matter
        """

        for path in security_conf_files():
            headers = parse_headers(path)
            policy = headers.get('Content-Security-Policy')
            if policy is None:
                continue

            directives = parse_csp(policy)
            for name in DIRECTIVES_THAT_MUST_NOT_BE_WILDCARD:
                sources = directives.get(name)
                if sources is None:
                    continue
                self.assertNotIn(
                    '*', sources,
                    f'{path.name}: the {name} directive allows every origin. '
                    f'A source list of * means an injected tag can load from '
                    f'or talk to anywhere, which is the finding this guards.'
                )

    def test_the_locked_down_directives_are_present(self):
        """
        The directives with nothing to lose must be set, and set correctly
        """

        for path in security_conf_files():
            headers = parse_headers(path)
            policy = headers.get('Content-Security-Policy')
            if policy is None:
                continue

            directives = parse_csp(policy)
            for name, expected in DIRECTIVES_THAT_MUST_BE_SET.items():
                self.assertIn(
                    name, directives,
                    f'{path.name}: the policy does not set {name}'
                )
                self.assertEqual(
                    directives[name], [expected],
                    f'{path.name}: {name} should be {expected}'
                )

    def test_default_src_is_self(self):
        """
        Anything not named by a more specific directive falls back to 'self'
        """

        for path in security_conf_files():
            headers = parse_headers(path)
            policy = headers.get('Content-Security-Policy')
            if policy is None:
                continue

            directives = parse_csp(policy)
            self.assertEqual(
                directives.get('default-src'), ["'self'"],
                f"{path.name}: default-src should be 'self' so that a "
                f'directive nobody thought of does not inherit a wide default'
            )


class TestHeaderValuesAreQuoted(unittest.TestCase):
    """
    A header value containing a semicolon has to be quoted or NGINX reads the
    rest of it as a new directive and refuses to start
    """

    def test_every_add_header_value_is_quoted(self):
        """
        Every add_header in these fragments uses a quoted value
        """

        for path in security_conf_files():
            for line in path.read_text().splitlines():
                stripped = line.strip()
                if not stripped.startswith('add_header'):
                    continue
                self.assertEqual(
                    stripped.count('"'), 2,
                    f'{path.name}: this add_header does not have exactly one '
                    f'quoted value, which will not parse: {stripped[:80]}'
                )

    def test_no_header_value_interpolates_a_variable(self):
        """
        None of these headers should depend on request state
        """

        for path in security_conf_files():
            for name, value in parse_headers(path).items():
                self.assertNotIn(
                    '$', value,
                    f'{path.name}: the {name} header interpolates a variable'
                )


if __name__ == '__main__':
    unittest.main()
