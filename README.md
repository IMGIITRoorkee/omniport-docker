<img src="readme-assets/site/wordmark.svg" height="98px" />

> The Docker of the one true portal for any and every educational institute

## Docker distribution

This is the official Docker distribution of Omniport. Do note that although 
every effort has been made to generalise this Docker container set, this 
distribution involves a lot of assumptions and sensible defaults, changing which 
will probably lead to a lot of anguish.

## Technological stack

- Framework: `Django`
- Language: `Python`
- Reverse proxy: `NGINX`
- WSGI server: `Gunicorn`
- ASGI server: `Daphne`
- Database: `PostgreSQL`
- Cache: `Memcached`
- In-memory store: `Redis`

This Dockerised setup is the preferred mode of installation. You can however set 
all the components up yourself, after suffering a reasonable amount of 
headbanging, cursing, and physical and mental pain.

## Contribution guidelines

- Fork the repository to your account.
- Branch out to `a_meaningful_branch_name`.
- Send in a `WIP: Pull request`.
- Commit your changes.
- Add your name to `CONTRIBUTORS.md`.
- Get your pull request merged.

It's that simple!

## Credits

<img src="readme-assets/maintainers/logo.svg" height="32px" /> <img src="readme-assets/maintainers/wordmark.svg" height="32px" />