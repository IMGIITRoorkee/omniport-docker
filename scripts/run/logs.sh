#!/bin/sh

# Get the current working directory
PWD=$(pwd)

# Get a name for the container, defaults to logs-prod
NAME=${1:-'logs-prod'}

# Run the container with the specified settings
# Examine logs!
docker run \
	--tty \
	--interactive \
	--rm \
	--net="host" \
	--name=$NAME \
	--mount type=volume,src=omniportdocker_gunicorn_logs,dst=/gunicorn_logs \
    --mount type=volume,src=omniportdocker_daphne_logs,dst=/daphne_logs \
	--mount type=volume,src=omniportdocker_nginx_logs,dst=/nginx_logs \
	alpine:latest \
	sh
