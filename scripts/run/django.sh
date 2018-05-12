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
	--env-file $PWD/environment/base.env \
	--env-file $PWD/environment/sites/intranet.env \
	--env DATABASE_HOST=127.0.0.1 \
	--env DATABASE_PORT=5432 \
	--env CHANNEL_LAYER_HOST=127.0.0.1 \
	--env CHANNEL_LAYER_PORT=6380 \
	--env SESSION_STORE_HOST=127.0.0.1 \
	--env SESSION_STORE_PORT=6381 \
	--mount type=bind,src=$PWD/omniport,dst=/omniport \
	--mount type=bind,src=$PWD/branding,dst=/omniport/omniport/static/omniport/branding \
	omniport-django:latest \
	python /omniport/manage.py runserver $PORT
