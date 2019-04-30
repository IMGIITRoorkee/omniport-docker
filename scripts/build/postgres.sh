#!/bin/bash

# Enter the Postgres Docker folder
cd postgres/

read -p "Rebuild database .env file? (y/N): " REBUILD
if [ $REBUILD == 'Y' -o $REBUILD == 'y' ]; then
    read -p "Enter the name of the database: " DB
    read -p "Enter the user of the database: " USER
    read -p "Enter the password of the database: " PASSWORD

    # Perform text substitution to generate the new .env file
    printf "Writing database environment file... "
    cp database_stencil.env database.env
    sed -i "s/\[\[db\]\]/${DB}/g" database.env
    sed -i "s/\[\[user\]\]/${USER}/g" database.env
    sed -i "s/\[\[password\]\]/${PASSWORD}/g" database.env
    printf "done\n"
fi

# Build the container from the Postgres folder and tag it
TIMESTAMP=$(date +"%s")

docker build \
    --tag omniport-postgres:${TIMESTAMP} \
    --tag omniport-postgres:latest \
    .