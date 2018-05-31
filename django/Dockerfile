# Use Python from the Debian Linux project
FROM python:slim-stretch

# Add labels for metadata
LABEL maintainer="Dhruv Bhanushali <https://dhruvkb.github.io/>"

# Install dependencies
RUN apt-get update \
    && apt-get install --no-install-recommends -y gcc supervisor \
    && rm -rf /var/lib/apt/lists/*

# Work in the root directory of the container
WORKDIR /

# Copy the requirements.txt file over to the container
# This command implies an image rebuild when requirements.txt changes
COPY ./requirements.txt ./requirements.txt

# Install pip packages
RUN pip install --upgrade pip \
    && pip install --requirement requirements.txt

# Copy the supervisord.conf file over to the container
COPY ./supervisord.conf ./supervisord.conf

# Copy the gunicorn_config.py file over to the container
COPY ./gunicorn_config.py ./gunicorn_config.py

# Define environment variables
ENV PYTHONPATH="/omniport:/omniport/core:/omniport/services:/omniport/apps"