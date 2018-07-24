# Omniport

## Docker distribution

This is the official Docker distribution of Omniport. Do note that although every effort has been made to generalise this Docker container set, this distribution involves a lot of assumptions and sensible defaults, changing which will probably lead to a lot of anguish and pain.

## Technological stack

- Framework: `Django 2`
- Language: `Python 3`
- Reverse proxy: `NGINX`
- WSGI server: `Gunicorn`
- ASGI server: `Daphne`
- Database: `PostgreSQL`

This Dockerised setup is the preferred mode of installation. You can however set all the components up yourself, after undergoing a reasonable amount of headbanging and physical and mental pain.

## Instructions

The following instructions should get your system up and running in no time at all! Unless otherwise specified, all commands must be run from the root directory. That means the directory containing this `README.md` file.

### Installation

You need to have Docker and Docker Compose installed on your system. Pro-tip: create the alias `dc=docker-compose` in your `.bashrc` file. 

Then for additional security, and to emulate the setup I have on my machine, edit the file `/etc/docker/daemon.json` as follows. Create the file if it does not exist already. Learn about user namespace remapping to better understand what this change does.

```json
{
	"userns-remap": "<user>"
}
```

Note that `<user>` here refers to the user you will be running Docker as. This is most likely your non-root administrator (UID 1000 in most cases). Check out the files `/etc/subuid` and `/etc/subgid` for a hint as to who this `<user>` is.

Then change directory to `/home` and ensure that the home directory of `<user>` has world execute permissions on it. It most likely won't so, grant the permission: `chmod o+x <user>/`. The goal is to ensure that all directories above and leading upto the project have the `x` permission enabled.

### Cloning repositories

Clone this repository itself into a folder preferably in your `~/Documents` or `/home/<user>` directory. Then change into `omniport-docker` and continue following the instructions. All commands must be executed from this directory, unless explicitly instructed otherwise.

Clone the repositories using the scripts in `./scripts/clone`. Go in the specified order.

- Clone the core: `./scripts/clone/core.sh`
- Clone the shell (for IIT Roorkee only): `./scripts/clone/shell.sh`
- Clone all the services: `./scripts/clone/services.sh`
- Clone only the apps you want: `git clone https://github.com/IMGIITRoorkee/omniport-app-xyz.git xyz` (*or over SSH if you prefer that*)

### Populating env vars

The configuration for the project is divided into 3 parts:

- **Message broker, `RabbitMQ`**:
    - Enter the RabbitMQ directory: `cd rabbitmq`
    - Create `message_broker.env` from `message_broker_stencil.env` and populate the message-broker username and password.
- **Database, `PostgreSQL`**:
    - Enter the PostgreSQL directory: `cd postgres`
    - Create `database.env` from `database_stencil.env` and populate the database name, username and password.
- **Web servers, `Gunicorn` and `Daphne`**:
    - Enter the YAML configuration files directory: `cd configuration`
    - Create `base.yml` from `base_stencil.yml`.
    - Enter the site-specific YAML configuration files directory: `cd sites`
    - For every site that is being run, create `site_<site_id>.yml` from `site_stencil.yml`.
    - You can override settings defined in `base.yml` by redefining them in `site_<site_id>.yml`.
    - If you are using the complete Docker setup, ensure that you use the same values defined in the `*.env` files from `postgres/` and `rabbitmq/`.
    
    | Site ID | Purpose                                                 |
    | ------- | ------------------------------------------------------- |
    | 0       | Omniport Development, used by `./scripts/run/django.sh` |
    | 1       | Omniport Intranet, the portal used on the Intranet      |
    | 2       | Omniport Internet, the portal used on the Internet      |

### Building containers

Since the `Django` and `NGINX` containers have been significantly modified from their base versions, they need to be built.

- Build the `Django` container: `./scripts/build/django.sh`
- Build the `NGINX` container: `./scripts/build/nginx.sh` 

### Launching containers

After building Docker containers, they need to be launched or *upped*.

- **Development**:
    - Launch all containers except `Django` and `NGINX`: `docker-compose up -d database session-store channel-layer message-broker`
    - Launch the `Django` development container: `./scripts/run/start-the-dj.sh`
- **Production**:
    - Just launch the entire system: `docker-compose up`

### Django housekeeping

For Django to become fully functional, a number of first time as well as periodic housekeeping tasks need to be performed.

- Enter the shell on the Django container.
    - **Development:** 
        - Find the ID of the Django container: `docker ps`
        - Enter the shell on the container: `docker exec -it <container_name> bash`
    - **Production:**
        - Enter the shell on the container: `docker-compose exec intranet-server bash`
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