#!/bin/sh

# Get the current working directory
PWD=$(pwd)

# Run the scaffolding services
docker-compose up -d \
    database \
    redis-gui \
    cache