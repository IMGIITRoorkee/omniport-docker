"""
Tests for the security response headers NGINX adds
"""

import pathlib
import re
import unittest
from urllib.parse import urlsplit

INCLUDES = pathlib.Path(__file__).resolve().parent.parent / 'nginx/conf.d/includes'
CONF = pathlib.Path(__file__).resolve().parent.parent / 'nginx/conf.d'

# Either spelling of the policy header. The enforcing one is the goal, the
# Report-Only one is how the part that can break something is rolled out.
ENFORCED_HEADER = 'Content-Security-Policy'
REPORTED_HEADER = 'Content-Security-Policy-Report-Only'
POLICY_HEADERS = (ENFORCED_HEADER, REPORTED_HEADER)

# The origin the policy is served from, for resolving 'self'.
SELF_ORIGIN = 'https://channeli.in'

# A source that lets an injected tag reach an origin nobody vetted: `*`, a
# bare scheme such as `https:`, a wildcard host such as `*.example.com`, or a
# scheme carrying one such as `https://*`.
BROAD_SOURCE = re.compile(
    r"^(\*"
    r"|\*\.[^\s]+"
    r"|[a-z][a-z0-9+.-]*:"
    r"|[a-z][a-z0-9+.-]*://\*(\.[^\s]+)?"
    r")$"
)

# The broad sources that are deliberate, per directive. Everything else is a
# regression back towards the wildcard policy this replaced.
ALLOWED_BROAD_SOURCES = {
    'img-src': {'data:', 'blob:', 'https:'},
    'font-src': {'data:'},
    'media-src': {'data:', 'blob:'},
    'frame-src': {'blob:'},
}

# Directives that must be enforced rather than reported. None of them governs
# a subresource load, so none of them can break a page by being wrong.
DIRECTIVES_THAT_MUST_BE_ENFORCED = {
    'object-src': "'none'",
    'base-uri': "'self'",
    'frame-ancestors': "'self'",
}

# form-action cannot be scoped: the allowed set is the redirect_uri column of
# the open_auth Application table, and Chromium enforces it across the 302 that
# ends every SSO grant. Setting it at all logs out every third-party client.
DIRECTIVES_THAT_MUST_NOT_BE_SET = ('form-action',)

# Directives that fall back to another one when absent, innermost first.
FALLBACKS = {
    'script-src': ('default-src',),
    'style-src': ('default-src',),
    'img-src': ('default-src',),
    'font-src': ('default-src',),
    'media-src': ('default-src',),
    'connect-src': ('default-src',),
    'frame-src': ('child-src', 'default-src'),
    'worker-src': ('child-src', 'script-src', 'default-src'),
}

# Every external subresource the deployed portal loads, with where it comes
# from. A directive that stops allowing one of these breaks that feature with
# nothing in any server log, which is the failure mode this file exists for.
PORTAL_LOADS = (
    (
        'script-src',
        'https://cdnjs.cloudflare.com/ajax/libs/Chart.js/3.2.0/chart.min.js',
        'omniport-frontend-new-forminator/src/index.js:16, injected by Helmet; '
        'form-results/components/question-response.js:57 calls new Chart()',
    ),
    (
        'script-src',
        'https://www.gstatic.com/firebasejs/6.3.4/firebase-messaging.js',
        'omniport-service-notifications/static/firebase-messaging-sw.js:1-2, '
        'importScripts inside the push service worker',
    ),
    (
        'connect-src',
        'https://en.gravatar.com/avatar/0123456789abcdef',
        'omniport-frontend-formula-one/src/urls.js:50, fetched over XHR by '
        'src/components/default-dp.js:31 for every avatar on every page',
    ),
    (
        'connect-src',
        'https://fcm.googleapis.com/fcm/connect/subscribe',
        'firebase messaging SDK, bundle chunk 4; getToken() in '
        'omniport-frontend-notifications/src/utils/push-notifications.js:10',
    ),
    (
        'connect-src',
        'https://tenor.googleapis.com/v2/search',
        'apps/dil urls.js in bundle chunk 1, the GIF picker',
    ),
    (
        'connect-src',
        'wss://channeli.in/ws/dil',
        'omniport-frontend-dil/src/urls.js:88, Django Channels over the proxy',
    ),
    (
        'style-src',
        'https://fonts.googleapis.com/css?family=Playfair+Display:700',
        'omniport-frontend-maintainer-site/src/css/app.css:1',
    ),
    (
        'style-src',
        'https://cdn.jsdelivr.net/npm/@typopro/web-bebas-neue@3.7.5/'
        'TypoPRO-BebasNeue.css',
        'omniport-frontend-maintainer-site/src/css/app.css:2',
    ),
    (
        'style-src',
        'https://cdn.rawgit.com/konpa/devicon/df6431e3/devicon.min.css',
        'omniport-frontend-maintainer-site/src/css/team/'
        'add-member-details.css:1',
    ),
    (
        'style-src',
        'https://fonts.cdnfonts.com/css/genty-demo',
        'apps/dil src/components/shoutbox/index.css in bundle chunk 1',
    ),
    (
        'font-src',
        'https://fonts.gstatic.com/s/playfairdisplay/v40/nuFvD.ttf',
        'the font files the fonts.googleapis.com stylesheet then pulls',
    ),
    (
        'font-src',
        'https://cdn.jsdelivr.net/gh/konpa/devicon@df6431e3/fonts/devicon.woff',
        'devicon.min.css has relative font URLs and cdn.rawgit.com 301s to '
        'cdn.jsdelivr.net, so they resolve against jsDelivr',
    ),
    (
        'font-src',
        'https://fonts.cdnfonts.com/s/genty-demo.woff',
        'the font files the fonts.cdnfonts.com stylesheet then pulls',
    ),
    (
        'img-src',
        'data:image/png;base64,iVBORw0KGgo=',
        'omniport-frontend-formula-one/src/components/default-dp.js:44-49, the '
        'gravatar bytes base64ed into a data URI',
    ),
    (
        'img-src',
        'blob:https://channeli.in/8f1a',
        'file previews in the file manager and r-drive',
    ),
    (
        'img-src',
        'https://omniport.readthedocs.io/en/latest/_static/favicon.ico',
        'omniport-frontend-formula-one/src/components/app-footer.js:130, in the '
        'portal frame on every route',
    ),
    (
        'img-src',
        'https://react.semantic-ui.com/images/wireframe/square-image.png',
        'omniport-frontend-bhawan-app/src/components/admin_authorities/'
        'index.js:143 and four siblings, the display-picture fallback',
    ),
    (
        'img-src',
        'https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/github.svg',
        'omniport-frontend-maintainer-site/src/components/team/link.js:38',
    ),
    (
        'img-src',
        'https://media.tenor.com/example.gif',
        'apps/dil urls.js in bundle chunk 1, posted GIFs',
    ),
    (
        'img-src',
        'https://i.pinimg.com/736x/07/c3/45/07c345d0eca11d0bc97c894751ba1b46.jpg',
        'omniport-frontend-slambook/src/components/Carousel.js:6-10, one of five '
        'image hosts',
    ),
    (
        'img-src',
        'https://any-host-a-notice-author-typed.example/photo.jpg',
        'the TinyMCE image plugin is enabled in omniport-backend/omniport/'
        'omniport/settings/third_party/tinymce.py:7, so rich text carries image '
        'URLs that live in the database and cannot be enumerated here',
    ),
    (
        'frame-src',
        'https://www.youtube.com/embed/AnxrJiS5uKU',
        'omniport-frontend-file-manager/src/components/app.js:72',
    ),
    (
        'frame-src',
        'https://open.spotify.com/embed/track/abc',
        'apps/dil urls.js in bundle chunk 1, the song player',
    ),
    (
        'frame-src',
        'blob:https://channeli.in/8f1a',
        'the PDF preview in placement-and-internship',
    ),
)


def security_conf_files():
    """
    Every include fragment that adds response headers
    """

    return sorted(INCLUDES.glob('security*.conf'))


HEADER_PATTERN = re.compile(
    r'^\s*add_header\s+(?P<name>[\w-]+)\s+"(?P<value>[^"]*)"', re.MULTILINE
)


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


def policies():
    """
    Yield the path, header name and parsed policy of every policy served
    """

    for path in security_conf_files():
        headers = parse_headers(path)
        for name in POLICY_HEADERS:
            if name in headers:
                yield path, name, parse_csp(headers[name])


def sources_for(directives, name):
    """
    The source list that governs a directive, following the CSP fallbacks
    """

    for candidate in (name,) + FALLBACKS.get(name, ()):
        if candidate in directives:
            return directives[candidate]
    return None


def allows(sources, url):
    """
    Whether a source list permits a URL, by the CSP source matching rules
    """

    target = urlsplit(url)
    for source in sources:
        if source.startswith("'"):
            # 'self' also covers the wss upgrade of the protecting origin
            if source == "'self'":
                protecting = urlsplit(SELF_ORIGIN)
                if target.scheme in ('https', 'wss'):
                    if target.netloc == protecting.netloc:
                        return True
                if url.startswith(f'blob:{SELF_ORIGIN}'):
                    return True
            continue
        if BROAD_SOURCE.match(source):
            if source == '*':
                return target.scheme not in ('data', 'blob', 'filesystem')
            if source.endswith(':'):
                if f'{target.scheme}:' == source:
                    return True
                continue
            if target.hostname and target.hostname.endswith(source[1:]):
                return True
            continue
        candidate = source if '//' in source else f'//{source}'
        if urlsplit(candidate).hostname == target.hostname:
            return True
    return False


class TestContentSecurityPolicy(unittest.TestCase):
    """
    The policy must name the origins it allows rather than allowing all of them
    """

    def test_every_fragment_carries_a_policy(self):
        """
        Every fragment adding headers must carry the policy, not just one

        NGINX drops the whole inherited add_header set when a level declares
        one of its own, so a fragment without the policy silently serves
        responses that have none.
        """

        for path in security_conf_files():
            headers = parse_headers(path)
            self.assertTrue(
                any(name in headers for name in POLICY_HEADERS),
                f'{path.name}: adds headers but no Content-Security-Policy, so '
                f'responses served through it carry no policy at all'
            )

    def test_no_directive_allows_an_unvetted_origin(self):
        """
        No directive may take `*`, a bare scheme or a wildcard host

        The exceptions in ALLOWED_BROAD_SOURCES are deliberate and listed.
        """

        for path, header, directives in policies():
            for name, sources in directives.items():
                allowed = ALLOWED_BROAD_SOURCES.get(name, set())
                for source in sources:
                    if not BROAD_SOURCE.match(source) or source in allowed:
                        continue
                    self.fail(
                        f'{path.name}: {header} {name} allows {source}, which '
                        f'lets an injected tag reach an origin nobody vetted. '
                        f'This is the wildcard policy back by a shorter name.'
                    )

    def test_the_locked_down_directives_are_enforced(self):
        """
        The directives with nothing to lose must be enforced, not reported
        """

        enforced = {
            name: sources
            for _, header, directives in policies()
            if header == ENFORCED_HEADER
            for name, sources in directives.items()
        }
        for name, expected in DIRECTIVES_THAT_MUST_BE_ENFORCED.items():
            self.assertEqual(
                enforced.get(name), [expected],
                f'{name} is not enforced as {expected}. It cannot break a page '
                f'by being wrong, so it does not belong in Report-Only.'
            )

    def test_a_default_src_of_self_is_served(self):
        """
        Anything not named by a more specific directive falls back to 'self'
        """

        defaults = [
            directives.get('default-src')
            for _, _, directives in policies()
            if 'default-src' in directives
        ]
        self.assertIn(
            ["'self'"], defaults,
            "no policy sets default-src 'self', so a directive nobody thought "
            'of inherits a wide default'
        )

    def test_form_action_is_not_set(self):
        """
        form-action breaks OAuth and cannot be scoped, so it must stay absent
        """

        for path, header, directives in policies():
            for name in DIRECTIVES_THAT_MUST_NOT_BE_SET:
                self.assertNotIn(
                    name, directives,
                    f'{path.name}: {header} sets {name}. Chromium enforces it '
                    f'across the 302 from /open_auth/authorise/ to the client, '
                    f'so every third-party Channel-i SSO login stops working.'
                )


class TestThePolicyAllowsWhatThePortalLoads(unittest.TestCase):
    """
    A directive tight enough to block a real subresource breaks it silently:
    no 4xx, nothing in the NGINX or Django logs, a console message only
    """

    def test_every_known_subresource_is_allowed(self):
        for path, header, directives in policies():
            for name, url, evidence in PORTAL_LOADS:
                sources = sources_for(directives, name)
                if sources is None:
                    # Nothing governs this load in this policy, so it is free
                    continue
                with self.subTest(policy=header, directive=name, url=url):
                    self.assertTrue(
                        allows(sources, url),
                        f'{path.name}: {header} {name} '
                        f'{" ".join(sources)} blocks {url}. From {evidence}'
                    )


class TestSourceMatching(unittest.TestCase):
    """
    The gate above is only worth as much as the matcher underneath it
    """

    def test_a_source_list_allows_what_it_names(self):
        cases = (
            (["'self'"], 'https://channeli.in/static/x.js'),
            (["'self'"], 'wss://channeli.in/ws/dil'),
            (["'self'"], 'blob:https://channeli.in/8f1a'),
            (['https://en.gravatar.com'], 'https://en.gravatar.com/avatar/0'),
            (['data:'], 'data:image/png;base64,iVBOR'),
            (['https:'], 'https://anything.example/photo.jpg'),
            (['*'], 'https://anything.example/photo.jpg'),
            (['*.tenor.com'], 'https://media.tenor.com/x.gif'),
        )
        for sources, url in cases:
            with self.subTest(sources=sources, url=url):
                self.assertTrue(allows(sources, url))

    def test_a_source_list_blocks_everything_else(self):
        cases = (
            (["'self'"], 'https://en.gravatar.com/avatar/0'),
            (["'self'", "'unsafe-inline'"], 'https://cdnjs.cloudflare.com/x.js'),
            (["'none'"], 'https://channeli.in/x.js'),
            (['https://en.gravatar.com'], 'https://gravatar.com/avatar/0'),
            (['https://en.gravatar.com'], 'https://en.gravatar.com.evil.tld/0'),
            (['data:'], 'https://anything.example/photo.jpg'),
            (['*'], 'data:image/png;base64,iVBOR'),
            (['*.tenor.com'], 'https://tenor.com.evil.tld/x.gif'),
        )
        for sources, url in cases:
            with self.subTest(sources=sources, url=url):
                self.assertFalse(allows(sources, url))

    def test_a_directive_falls_back_the_way_browsers_do(self):
        directives = {'default-src': ["'self'"], 'child-src': ['blob:']}
        self.assertEqual(sources_for(directives, 'img-src'), ["'self'"])
        self.assertEqual(sources_for(directives, 'frame-src'), ['blob:'])
        self.assertIsNone(sources_for(directives, 'form-action'))


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

    def test_no_other_fragment_adds_a_header(self):
        """
        An add_header anywhere else drops the whole set for that location
        """

        for path in sorted(CONF.rglob('*.conf')):
            if path.match('includes/security*.conf'):
                continue
            for number, line in enumerate(path.read_text().splitlines(), 1):
                self.assertNotIn(
                    'add_header', line.split('#', 1)[0],
                    f'{path.name}:{number} adds a header outside '
                    f'security.conf, which drops the inherited security '
                    f'headers for every response it serves'
                )


if __name__ == '__main__':
    unittest.main()
