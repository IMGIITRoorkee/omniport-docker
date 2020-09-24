#!/bin/sh

# Run the scaffolding services
docker-compose up -d \
    database \
    redis-gui \
    cache \
    message-broker
