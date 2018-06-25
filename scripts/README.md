# Scripts

This folder contains a bunch of shell scripts to perform some repetitive operations such as building Docker images and running transient containers. All these scripts are written assuming them to be executed from the root folder, namely `omniport-docker/`.

Folder structure:
- clone/
    - `core.sh`: Clone the core of the Omniport project from GitHub, into a folder named `omniport/` in the root directory.
    - `shell.sh`: Clone the Omniport shell specific to IIT Roorkee from GitHub, into a folder named `shell/`, inside the `omniport/` folder created by the `core.sh` script.
    - `services.sh`: Clone the various services of the Omniport project into their respective folders inside the folder `services/`, inside the `omniport/` directory.
- build/
    - `django.sh`: Build the Django container from the Dockerfile present in the `django/` folder inside the project root.
    - `nginx.sh`: Build the NGINX container from the Dockerfile present in the `nginx/` folder inside the project root.
- run/
    - `django.sh`: Run a temporal Django web-server container with development settings. Optionally takes the following command-line arguments:
        - a name for the container, defaults to `django-dev`
        - the interface and port to bind to, defaults to `0.0.0.0:8000`
    - `logs.sh`: Run a temportal Alpine container to inspect logs created by various containers. Optionally takes the following command-line arguments:
        - a name for the container, defaults to `logs-prod`
- clean/
    - `unclone.sh`: Removes the `omniport/` directory from the root directory. This will remove the Omniport core, the shell, all services and any apps you might have cloned into the code base.