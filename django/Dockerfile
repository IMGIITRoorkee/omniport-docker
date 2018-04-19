# Use Python from the Alpine Linux project
FROM python:alpine

# Add labels for metadata
LABEL maintainer="Dhruv Bhanushali <https://dhruvkb.github.io/>"

# Work in the root directory of the container
WORKDIR /

# Copy the requirements.txt file over to the container
# This command implies an image rebuild when requirements.txt changes
COPY ./omniport/requirements.txt ./requirements.txt

# Install dependencies
RUN apk update \
    && apk upgrade \
    && apk add --no-cache --virtual .removable-dependencies \
    build-base gcc libffi-dev musl-dev \
    && apk add --no-cache --virtual .permanent-dependencies \
    postgresql-dev jpeg-dev zlib-dev supervisor \
    && pip install --upgrade pip \
    && pip install --requirement requirements.txt \
    && apk del .removable-dependencies

# Copy the supervisord.conf file over to the container
COPY ./django/supervisord.conf ./supervisord.conf

# Define environment variables
ENV PYTHONPATH="/omniport:/omniport/apps:/omniport/services"