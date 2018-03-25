#!/bin/sh

# Build the container from the nginx folder and tag it
docker build --file nginx/Dockerfile --tag omniport-nginx .
