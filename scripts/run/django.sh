#!/bin/sh

# Get the current working directory
PWD=$(pwd)

# Get the port on which to run the development server, defaults to 8000
PORT=$1

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
	python /omniport/manage.py runserver $PORT
