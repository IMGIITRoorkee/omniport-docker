# Django

Docker service name: `intranet-server` and `internet-server`

Running applications:
- `Gunicorn`
- `Daphne`
- `Supervisor`

Folder contents:
- `Dockerfile`: A Dockerfile is the recipe to build a Docker image.
- `gunicorn_config.py`: This file contains configuration parameters for `Gunicorn` such as the binding interface and the port.
- `supervisord.conf`: This file contains configuration parameters for `Supervisor` such as the software to run and the settings to run them with.

## Description

Omniport serves application requests through either `Gunicorn` or `Daphne`, managed by `Supervisor`.  This folder contains the Dockerfile required to build the image.

The decision of the upstream server is based on whether the request is a plain old HTTP request (`Gunicorn` has the speed to beat) or whether it requires HTTP/2 and related technology like WebSockets and Long-polling (which are `Daphne`'s core strength). `Supervisor` makes sure both services are kept up at the specified ports, so that `NGINX` can proxy the request to the right upstream server.