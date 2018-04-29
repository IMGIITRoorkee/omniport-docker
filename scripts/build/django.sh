#!/bin/sh

# Build the container from the django folder and tag it
docker build --file django/Dockerfile --tag omniport-django .
