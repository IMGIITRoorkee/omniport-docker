"""
Mock Omniport deployment for exercising test_pr_verification.sh.

    python3 mock_pr_deployment.py fixed      8911
    python3 mock_pr_deployment.py vulnerable 8912
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MODE = sys.argv[1]
PORT = int(sys.argv[2])

# Routes that must answer without a session even after default-deny
PUBLIC = (
    '/session_auth/login/',
    '/session_auth/illustration_roulette/',
    '/bootstrap/site_branding/',
    '/bootstrap/institute_branding/',
    '/bootstrap/maintainers_branding/',
    '/base_auth/recover_password/',
    '/base_auth/verify/',
    '/base_auth/reset_password/',
    '/base_auth/verify_secret_answer/',
    '/hello/',
    '/ensure_csrf/',
    '/manifest/',
    '/api/gif/roulette/',
    '/api/registration/create_session',
    '/api/registration/set_pass',
    '/api/pseudoc/registration/',
    '/api/maintainer_site/blog/',
    '/api/maintainer_site/social/',
    '/api/maintainer_site/location/',
    '/api/maintainer_site/contact/',
    '/api/maintainer_site/maintainer_group/',
    '/api/maintainer_site/active_maintainer_info/',
    '/api/maintainer_site/projects/',
)

LOST_ITEMS = {
    'results': [
        {'id': 1, 'heading': 'wallet', 'contactVisible': False,
         'emailAddress': '', 'primaryPhoneNumber': '', 'fullName': 'A Person'},
        {'id': 2, 'heading': 'keys', 'contactVisible': True,
         'emailAddress': 'owner@iitr.ac.in', 'primaryPhoneNumber': '9990000001',
         'fullName': 'B Person'},
    ]
}

LEAKY_ITEMS = {
    'results': [
        {'id': 1, 'heading': 'wallet', 'contactVisible': False,
         'emailAddress': 'owner@iitr.ac.in', 'primaryPhoneNumber': '',
         'fullName': 'A Person'},
    ]
}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, code, payload=None, extra=(), html=False):
        if html:
            body = b'<!doctype html><html></html>'
        else:
            body = json.dumps(payload).encode() if payload is not None else b'{}'
        self.send_response(code)
        self.send_header(
            'Content-Type',
            'text/html; charset=utf-8' if html else 'application/json')
        for name, value in extra:
            self.send_header(name, value)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        if self.command != 'HEAD':
            self.wfile.write(body)

    @property
    def authed(self):
        return 'sessionid=' in self.headers.get('Cookie', '')

    def handle_one(self):
        path = self.path.split('?')[0]
        vulnerable = MODE == 'vulnerable'

        if path == '/':
            return self._send(200, html=True)

        # An unrouted path: the bundle answers, not Django
        if path == '/api/noticeboard/unrouted/':
            return self._send(200, html=True)

        # ensure_csrf must set the cookie
        if path == '/ensure_csrf/':
            return self._send(200, {}, [('Set-Cookie', 'csrftoken=abc; Path=/')])

        # OPTIONS metadata for the maintainer site
        if self.command == 'OPTIONS':
            if vulnerable:
                return self._send(200, {'name': 'x'})          # actions dropped
            return self._send(200, {'name': 'x', 'actions': {'POST': {}}})

        # lost and found payloads
        if path == '/api/lost_and_found/lostitem/':
            return self._send(200, LEAKY_ITEMS if vulnerable else LOST_ITEMS)
        if path == '/api/lost_and_found/founditem/':
            return self._send(200, LEAKY_ITEMS if vulnerable else LOST_ITEMS)
        if path.endswith('/getItem/'):
            return self._send(200 if vulnerable else 404)
        if path == '/api/lost_and_found/lostitem/change_status/':
            return self._send(200 if vulnerable else 403)

        # people search rows
        if path == '/api/people_search/student_search/':
            if not self.authed:
                return self._send(401)
            if vulnerable:
                return self._send(200, {'results': [
                    {'id': 1, 'primaryEmailId': ['non'], 'bhawan': ['non']}]})
            return self._send(200, {'results': [{'id': 1}]})
        if path.startswith('/api/people_search/faculty_search/'):
            if not self.authed:
                return self._send(401)
            if self.command in ('POST', 'PUT', 'PATCH', 'DELETE'):
                return self._send(200 if vulnerable else 405)
            return self._send(200)

        # default deny surface
        if path in ('/api/lost_and_found/categories/',
                    '/api/lost_and_found/recent_feed/'):
            if self.authed:
                return self._send(200)
            return self._send(200 if vulnerable else 401)

        if path.startswith('/api/student_profile/'):
            return self._send(200 if vulnerable else 403)

        if path.startswith('/api/pseudoc/update_user/'):
            return self._send(400 if vulnerable else 403)

        if path.startswith('/api/maintainer_site/hit/'):
            return self._send(204 if vulnerable else 403)

        if path.startswith('/api/django_filemanager/folder/get_root/'):
            return self._send(200 if self.authed else 401)

        if path in PUBLIC:
            return self._send(200)

        if self.authed:
            return self._send(200, {'results': []})

        return self._send(401, {'detail': 'Authentication credentials were not provided.'})

    def do_GET(self):
        self.handle_one()

    do_POST = do_PUT = do_PATCH = do_DELETE = do_OPTIONS = do_HEAD = do_GET


ThreadingHTTPServer.allow_reuse_address = True
ThreadingHTTPServer(('127.0.0.1', PORT), Handler).serve_forever()
