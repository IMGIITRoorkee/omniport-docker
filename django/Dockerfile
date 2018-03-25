# Use Python from the Alpine Linux project
FROM python:alpine

# Add labels for metadata
LABEL maintainer="Dhruv Bhanushali <https://dhruvkb.github.io/>"

# Expose port 8000 on which Gunicorn serves the Django application
EXPOSE 8000

# Define environment variables
ENV PYTHONPATH="/omniport:/omniport/apps"

# Work in the root directory of the container
WORKDIR /

# Copy the requirements.txt file over to the container
# This command implies an image rebuild when requirements.txt changes
COPY ./omniport/requirements.txt ./requirements.txt

# Install dependencies
RUN apk update \
    && apk upgrade \
    && apk add --no-cache --virtual .dependencies \
    build-base gcc postgresql-dev libffi-dev musl-dev jpeg-dev zlib-dev bash

# Upgrade pip, if an upgrade is out
RUN ["pip", "install", "--upgrade", "pip"]

# Install packages listed in requirements.txt
RUN ["pip", "install", "--requirement", "requirements.txt"]
