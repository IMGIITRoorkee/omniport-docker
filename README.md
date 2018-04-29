# Omniport 
## Docker distribution

This is the official Docker distribution of Omniport. Do note that although every effort has been made to generalise this Docker container set, this distribution involves a lot of assumptions and sensible defaults, changing which will probably lead to a lot of anguish and pain.

## Technological stack

- Framework: `Django 2`
- Language: `Python 3`
- Reverse proxy: `NGINX`
- WSGI server: `Gunicorn`
- ASGI server: `Daphne`
- Database: `PostgreSQL` + `Psycopg2`

This Dockerised setup is the preferred mode of installation.

## Instructions

- Run the following scripts _from the root folder_, in this order
    - `clone/core.sh`
    - `clone/shell.sh` (optional; if you want the IIT Roorkee customisations)
    - `build-django.sh`
    - `build-nginx.sh`
- Run `docker-compose up`
- If this is your first run, enter `docker-compose exec <django-container> /bin/bash` and then run the following `manage.py` commands
    - `collectstatic`
    - `makemigrations` 
    - `migrate`
    - `createsuperuser`

## Contribution guidelines

- Fork the repository to your account.
- Branch out to `a_meaningful_branch_name`.
- Send in a `WIP: Pull request`.
- Commit your changes.
- Add your name to `CONTRIBUTORS.md`.
- Get your pull request merged.

It's that simple!

## Contribution ideas

- Decouple this from the Omniport project and make it generalized enough to support any Django project that needs some simple architecture like a database, an in-memory data store, HTTP 2.0 support and a reverse proxy.
- Allow any number of sites to be spawned simply by placing their environment files in the site-specific environment files directory, with the rest of the settings taking up the data from there directly.
- Any other idea that you think will take the project forward.