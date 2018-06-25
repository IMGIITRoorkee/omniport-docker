# NGINX

Docker service name: `reverse-proxy`

Running applications:
- `NGINX`

Folder contents:
- `Dockerfile`: A Dockerfile is the recipe to build a Docker image.
- conf.d/
    - `01-intranet.conf`: The NGINX configuration of the Intranet site, which is to be processed first as it is the inner network ring with higher privileges. 
    - `02-internet.conf`: The NGINX configuration of the Internet site, which is to be processed second as it is the outer network ring with lower privileges.

## Description

`NGINX` is the reverse-proxy used by Omniport. This folder contains the Dockerfile required to build the image.

`NGINX` serves the static and media files itself. It also serves the frontend bundles. But it routes all application requests upstream to the `Gunicorn` on `Daphne` servers running on the Django containers.
