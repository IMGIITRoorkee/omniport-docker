#!/bin/sh

# Enter the NGINX Docker folder
cd nginx/

# Build the container from the nginx folder and tag it
TIMESTAMP=$(date +"%s")
docker build --tag omniport-nginx:${TIMESTAMP} --tag omniport-nginx:latest .
