"""
Mock Omniport deployment, in a vulnerable or a fixed configuration, so the
shell script can be checked for whether it actually discriminates between them.

    python3 mock_server.py vulnerable 8901
    python3 mock_server.py fixed      8902
"""
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MODE = sys.argv[1]
PORT = int(sys.argv[2])

VULNERABLE_CSP = "default-src * blob: data: 'unsafe-eval' 'unsafe-inline'"
FIXED_CSP = (
    "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; "
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com "
    "https://cdn.jsdelivr.net https://cdn.rawgit.com; "
    "img-src 'self' data: blob: https://cdn.jsdelivr.net; "
    "font-src 'self' data: https://fonts.gstatic.com https://cdn.jsdelivr.net "
    "https://cdn.rawgit.com; media-src 'self' data: blob:; "
    "connect-src 'self'; frame-src 'self' blob: https://www.youtube.com; "
    "object-src 'none'; base-uri 'self'; form-action 'self'; "
    "frame-ancestors 'self'"
)

NOTICE_ROUTES = (
    '/api/noticeboard/new/', '/api/noticeboard/old/',
    '/api/noticeboard/filter_list/', '/api/noticeboard/filter/',
    '/api/noticeboard/date_filter_view/',
    '/api/noticeboard/institute_notices/',
    '/api/noticeboard/star_filter_view/',
)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, code, body=b'', extra_headers=()):
        self.send_response(code)
        csp = VULNERABLE_CSP if MODE == 'vulnerable' else FIXED_CSP
        self.send_header('Content-Security-Policy', csp)
        self.send_header('X-Frame-Options', 'SAMEORIGIN')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'strict-origin-when-cross-origin')
        self.send_header('Strict-Transport-Security', 'max-age=31536000')
        for name, value in extra_headers:
            self.send_header(name, value)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        if self.command != 'HEAD':
            self.wfile.write(body)

    def do_GET(self):
        path = self.path.split('?')[0]
        authenticated = 'sessionid=' in self.headers.get('Cookie', '')

        if path.startswith('/api/noticeboard/'):
            is_notice_route = (
                path in NOTICE_ROUTES or path.startswith('/api/noticeboard/new/')
            )
            if is_notice_route:
                if MODE == 'vulnerable' or authenticated:
                    self._send(200, b'{"count":19276,"results":[]}')
                else:
                    self._send(401, b'{"detail":"Authentication credentials '
                                    b'were not provided."}')
                return

        if path == '/api/kernel/who_am_i/':
            self._send(401 if not authenticated else 200, b'{}')
            return

        if path.startswith('/static/'):
            self._send(200, b'asset')
            return

        self._send(200, b'<html></html>')

    do_HEAD = do_GET


ThreadingHTTPServer.allow_reuse_address = True
ThreadingHTTPServer(('127.0.0.1', PORT), Handler).serve_forever()
