#!/bin/bash

# Enter the Memcached Docker folder
cd memcached/

# Build the container from the Memcached folder and tag it
TIMESTAMP=$(date +"%s")

docker build \
    --tag omniport-memcached:${TIMESTAMP} \
    --tag omniport-memcached:latest \
    .