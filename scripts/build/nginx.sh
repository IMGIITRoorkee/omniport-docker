#!/bin/sh

# Enter the NGINX Docker folder
cd nginx/

# Build the container from the nginx folder and tag it
docker build --tag omniport-nginx .
