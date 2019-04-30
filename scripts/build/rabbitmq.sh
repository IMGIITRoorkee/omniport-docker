#!/bin/bash

# Enter the RabbitMQ Docker folder
cd rabbitmq/

read -p "Rebuild message broker .env file? (y/N): " REBUILD
if [ $REBUILD == 'Y' -o $REBUILD == 'y' ]; then
    read -p "Enter the user of the message broker: " USER
    read -p "Enter the pass of the message broker: " PASS

    # Perform text substitution to generate the new .env file
    printf "Writing message broker environment file... "
    cp message_broker_stencil.env message_broker.env
    sed -i "s/\[\[user\]\]/${USER}/g" message_broker.env
    sed -i "s/\[\[pass\]\]/${PASS}/g" message_broker.env
    printf "done\n"
fi

# Build the container from the RabbitMQ folder and tag it
TIMESTAMP=$(date +"%s")

docker build \
    --tag omniport-rabbitmq:${TIMESTAMP} \
    --tag omniport-rabbitmq:latest \
    .