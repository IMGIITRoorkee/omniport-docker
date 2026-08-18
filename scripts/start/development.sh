#!/bin/sh

# Run the scaffolding services
docker-compose up -d \
    database \
    cache \
    message-broker \
    elasticsearch
