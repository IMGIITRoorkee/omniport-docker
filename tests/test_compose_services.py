"""
Tests for the service definitions in docker-compose.yml
"""

import pathlib
import shlex
import unittest

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
COMPOSE = ROOT / 'docker-compose.yml'
STARTUP_SCRIPT = ROOT / 'scripts' / 'start' / 'development.sh'

# Ports that must never be published to the host. Each entry is the container
# port and the reason it is forbidden, which is printed on failure so that
# whoever trips the test knows why the rule exists.
#
# 15672, the RabbitMQ console, is knowingly not on this list: it is credentialed
# from a deployment env file, and unpublishing it is an operator-facing change.
FORBIDDEN_PUBLISHED_PORTS = {
    '8081': (
        'Redis Commander. It ships with no credentials, and REDIS_HOSTS gave '
        'it every Redis instance in the deployment, including the session '
        'store, so publishing it hands out session hijacking to anyone who '
        'can reach the host.'
    ),
    '6379': (
        'Redis. The stores hold sessions and password recovery tokens and are '
        'reachable on the compose network already; they must not be exposed '
        'to the host as well.'
    ),
    '5432': (
        'PostgreSQL. It is reachable on the compose network and has no place '
        'on the host interface.'
    ),
}


class ComposeFileTestCase(unittest.TestCase):
    """
    Base class that loads the compose file once
    """

    @classmethod
    def setUpClass(cls):
        with open(COMPOSE) as compose_file:
            cls.compose = yaml.safe_load(compose_file)
        cls.services = cls.compose.get('services', {})

    @staticmethod
    def published_ports(service):
        """
        Return the set of container ports a service publishes to the host

        Compose accepts `"8081:8081"`, `8081`, and the long form mapping, so
        all three shapes are normalised here rather than at the call site.
        """

        published = set()
        for mapping in service.get('ports', []) or []:
            if isinstance(mapping, dict):
                target = mapping.get('target')
                if target is not None:
                    published.add(str(target))
                continue

            mapping = str(mapping)
            # host:container, ip:host:container, or a bare container port
            parts = mapping.split(':')
            published.add(parts[-1].split('/')[0])

        return published


class TestForbiddenPortsAndServices(ComposeFileTestCase):
    """
    No forbidden port reaches the host and Redis Commander is not defined
    """

    def test_redis_commander_service_is_absent(self):
        """
        Redis Commander must not be defined at all
        """

        for name, service in self.services.items():
            image = str(service.get('image', ''))
            self.assertNotIn(
                'redis-commander', image,
                f'the service {name!r} runs Redis Commander, which must not be '
                f'part of the deployment'
            )
            self.assertNotEqual(
                name, 'redis-gui',
                'the redis-gui service is Redis Commander under another name'
            )

    def test_no_forbidden_port_is_published(self):
        """
        No service may publish one of the forbidden ports to the host
        """

        for name, service in self.services.items():
            published = self.published_ports(service)
            for port, reason in FORBIDDEN_PUBLISHED_PORTS.items():
                self.assertNotIn(
                    port, published,
                    f'the service {name!r} publishes port {port} to the host. '
                    f'{reason}'
                )


class TestStartupScriptNamesRealServices(ComposeFileTestCase):
    """
    The bootstrap script must only name services the compose file defines
    """

    @staticmethod
    def named_services(source):
        """
        Return the service names a shell script passes to `docker-compose up`

        The line continuations are joined first because `shlex` keeps the
        escaped newline as a token of its own.
        """

        tokens = shlex.split(source.replace('\\\n', ' '), comments=True)
        if 'up' not in tokens:
            return []

        return [
            token
            for token in tokens[tokens.index('up') + 1:]
            if not token.startswith('-')
        ]

    def test_the_development_script_names_only_defined_services(self):
        """
        Compose resolves every name before it starts anything, so one stale
        name aborts the command and nothing at all comes up
        """

        named = self.named_services(STARTUP_SCRIPT.read_text())
        self.assertTrue(
            named,
            f'no service names were found in {STARTUP_SCRIPT.name}, so this '
            f'test is not checking anything'
        )

        unknown = [name for name in named if name not in self.services]
        self.assertFalse(
            unknown,
            f'{STARTUP_SCRIPT.name} starts {unknown}, which the compose file '
            f'does not define'
        )


class TestComposeFileIsWellFormed(ComposeFileTestCase):
    """
    Guard rails so that the tests above cannot pass on a file that no longer
    describes the deployment
    """

    def test_the_expected_services_are_still_defined(self):
        """
        Removing a service must not silently satisfy the rules above
        """

        for name in ('database', 'session-store', 'reverse-proxy'):
            self.assertIn(
                name, self.services,
                f'the {name!r} service has gone missing from the compose file'
            )

    def test_every_service_declares_an_image_or_a_build(self):
        """
        Every service must be runnable
        """

        for name, service in self.services.items():
            self.assertTrue(
                service.get('image') or service.get('build'),
                f'the service {name!r} declares neither an image nor a build'
            )


if __name__ == '__main__':
    unittest.main()
