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

The following instructions should get your system up and running in no time at all!

### Cloning repositories

Clone the repositories using the scripts in `./scripts/clone`. Go in the specified order.

- Clone the core: `omniport-core`
- Clone the shell (for IIT Roorkee only): `omniport-shell`
- Clone all the services: `omniport-service-*`
- Clone only the apps you want: `omniport-app-*`

### Populating env vars

This section is under development because of an impending plan to shift away from environment variables to JSON configuration files.

### Building containers

Since the `Django` and `NGINX` contains have been significantly modified from their base versions, they need to be built.

- Build the `Django` container: `./scripts/build/django.sh`
- Build the `NGINX` container: `./scripts/build/nginx.sh` 

### Launching containers

After building Docker containers, they need to be launched or *upped*.

- **Development**:
    - Launch all containers except `Django` and `NGINX`: `docker-compose up -d database session-store channel-layer`
    - Launch the `Django` development container: `./scripts/run/start-the-dj.sh`
- **Production**:
    - Just launch the entire system: `docker-compose up`

### Django housekeeping

For Django to become fully functional, a number of first time as well as periodic housekeeping tasks need to be performed.

- Enter the shell on the Django container.
    - **Development:** 
        - Find the ID of the Django container: `docker ps`
        - Enter the shell on the container: `docker exec <container_id> sh`
    - **Production:**
        - Enter the shell on the container: `docker-compose exec intranet-server sh`
- Enter the Omniport directory: `cd omniport`
- Run all the `manage.py` commands you need.
    - `collectstatic`
    - `makemigrations`
    - `migrate`
    - `createsuperuser`

### Logs

In case things go sideways, the logs must be the first place to check. They can be viewed in one of two ways, depending on the environment.

- **Development:**
    - The logs just appear on the screen! What more do you want?
- **Production:**
    - Launch the `Logs` container: `./scripts/run/logs.sh`
    - Enter the logs directory of the service that broke down.
        - `Gunicorn`: `cd gunicorn_logs`
        - `Daphne`: `cd daphne_logs`
        - `NGiNX`: `cd nginx_logs`
    - See all log files: `ls`
    - Tail whatever log file suits your fancy and the case: `tail -f <filename>`

## Contribution guidelines

- Fork the repository to your account.
- Branch out to `a_meaningful_branch_name`.
- Send in a `WIP: Pull request`.
- Commit your changes.
- Add your name to `CONTRIBUTORS.md`.
- Get your pull request merged.

It's that simple!

## Contribution ideas

- Generalized it further so that it becomes the go-to Docker configuration for any Django project that needs some simple architecture like a database, an in-memory data store, HTTP 2.0 support and a reverse proxy.
- Allow any number of sites to be spawned simply by placing their environment files in the site-specific environment files directory, with the rest of the settings taking up the data from there directly.
- Any other idea that you think will take the project forward, albeit after discussion in the Issues section and on individual PRs as well.