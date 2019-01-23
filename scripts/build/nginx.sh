#!/bin/bash

# Enter the NGINX Docker folder
cd nginx/

read -p "Rebuild NGINX .conf files? (y/N): " REBUILD
if [ $REBUILD == 'Y' -o $REBUILD == 'y' ]; then
    read -p "Enter the domain name for the intranet site as '.omniport.intranet': " INTRANET_DOMAIN
    read -p "Enter the domain name for the Internet site as '.omniport.internet': " INTERNET_DOMAIN

    # Enter conf.d/ inside the NGINX Docker folder
    cd conf.d/

    # Remove pre-existing .conf files
    rm 01-intranet.conf 02-internet.conf

    # Perform text substitution to generate the new .conf files
    cp stencils/01-intranet.conf ./01-intranet.conf
    sed -i "s/\[\[intranet_domain\]\]/${INTRANET_DOMAIN}/g" 01-intranet.conf
    cp stencils/02-internet.conf ./02-internet.conf
    sed -i "s/\[\[internet_domain\]\]/${INTERNET_DOMAIN}/g" 02-internet.conf

    # Get back out
    cd ..
fi

# Build the container from the nginx folder and tag it
TIMESTAMP=$(date +"%s")

docker build \
    --tag omniport-nginx:${TIMESTAMP} \
    --tag omniport-nginx:latest \
    .