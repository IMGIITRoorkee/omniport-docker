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
	--network=omniport-docker_default \
	--mount type=volume,src=omniport-docker_reverse_proxy_logs,dst=/reverse_proxy_logs \
    --mount type=volume,src=omniport-docker_web_server_logs,dst=/web_server_logs \
	--name=$NAME \
	alpine:latest \
	sh
