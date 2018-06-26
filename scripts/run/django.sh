#!/bin/sh

# Get the current working directory
PWD=$(pwd)

# Get a name for the container, defaults to django-dev
NAME=${1:-'django-dev'}

# Get the interface and port to bind to, defaults to 0.0.0.0:8000
BIND=${2:-'0.0.0.0:8000'}

# Run the container with the specified settings
# Start the DJ!
docker run \
	--tty \
	--interactive \
	--rm \
    --user=django:django \
	--network=omniport-docker_default \
	--mount type=bind,src=$PWD/omniport,dst=/omniport \
	--mount type=bind,src=$PWD/configuration,dst=/omniport/configuration \
	--mount type=bind,src=$PWD/branding,dst=/omniport/omniport/static/omniport/branding \
	--mount type=volume,src=omniportdocker_media,dst=/media \
	--name=$NAME \
	--env SITE_ID=0 \
	omniport-django:latest \
	python /omniport/manage.py runserver $BIND
