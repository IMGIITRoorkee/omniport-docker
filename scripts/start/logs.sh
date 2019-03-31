#!/bin/sh

# Get a name for the container
NAME=logs-$(date +"%s")

# Run the container to explore and monitor logs
docker run \
	--tty \
	--interactive \
	--rm \
	--mount type=volume,src=omniport-docker_reverse_proxy_logs,dst=/reverse_proxy_logs \
	--mount type=volume,src=omniport-docker_web_server_logs,dst=/web_server_logs \
	--name ${NAME} \
	bash:latest \
	bash
