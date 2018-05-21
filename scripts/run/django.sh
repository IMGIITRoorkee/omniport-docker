#!/bin/sh

# Get the current working directory
PWD=$(pwd)

# Get the interface and port to bind to, defaults to 0.0.0.0:8000
BIND=${1:-'0.0.0.0:8000'}

# Run the container with the specified settings
# Start the DJ!
docker run \
	--tty \
	--interactive \
	--net="host" \
	--env SITE_ID=0 \
	--mount type=bind,src=$PWD/omniport,dst=/omniport \
	--mount type=bind,src=$PWD/configuration,dst=/omniport/configuration \
	--mount type=bind,src=$PWD/branding,dst=/omniport/omniport/static/omniport/branding \
	omniport-django:latest \
	python /omniport/manage.py runserver $BIND
