#!/bin/bash

# Enter the Redis Docker folder
cd redis/

# Build the container from the Redis folder and tag it
TIMESTAMP=$(date +"%s")

docker build \
    --tag omniport-redis:${TIMESTAMP} \
    --tag omniport-redis:latest \
    .