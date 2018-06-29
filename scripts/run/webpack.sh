#!/bin/sh

# Get the current working directory
PWD=$(pwd)

# Get the name of the app directory
DIR=${1:-'omnifront'}

# Get the underscored app name 
APP=${2:-'omnifront'}

# Run the container with the specified settings
docker run \
	--tty \
	--interactive \
	--rm \
	--network=omniport-docker_default \
	--publish 3000:3000/tcp \
	--mount type=bind,src=$PWD/$DIR,dst=/$DIR \
	--mount type=volume,src=omniport-docker_frontend,dst=/frontend \
	--name=$NAME \
	--workdir=/$DIR \
	--env DIR=$DIR \
	--env APP=$APP \
	node:alpine \
	sh -c 'yarn build && rm -rf /frontend/$APP ; cp -r build/ /frontend/$APP'
