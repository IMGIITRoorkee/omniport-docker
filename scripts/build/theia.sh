#!/bin/sh

# Enter the Thiea Docker folder
cd theia/

# Build the container from theia folder and tag it
TIMESTAMP=$(date +"%s")
docker build --tag omniport-theia:${TIMESTAMP} --tag omniport-theia:latest .