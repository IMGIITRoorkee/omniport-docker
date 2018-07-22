# Use Python from the Debian Linux project
FROM python:3.6-slim-stretch

# Add labels for metadata
LABEL maintainer="Dhruv Bhanushali <https://dhruvkb.github.io/>"

# Create a non-root user
RUN groupadd --system django && useradd --system --gid django django

# Install dependencies
RUN apt-get update \
    && apt-get install -y gcc supervisor \
    && rm -rf /var/lib/apt/lists/*

# Work in the root directory of the container
WORKDIR /

# Copy the requirements.txt file over to the container
# This command implies an image rebuild when requirements.txt changes
COPY ./requirements.txt ./requirements.txt

# Install pip packages
RUN pip install --upgrade pip \
    && pip install --requirement requirements.txt

# Create the static files volume as a directory
RUN mkdir -p /static_files \
    && chown django:django /static_files \
    && chmod -R o+r /static_files

# Create the media files volume as a directory
RUN mkdir -p /media_files \
    && chown -R django:django /media_files \
    && chmod -R o+r /media_files

# Create the web server logs volume as a directory
RUN mkdir -p /web_server_logs/supervisord_logs  \
    && mkdir -p /web_server_logs/gunicorn_logs \
    && mkdir -p /web_server_logs/daphne_logs \
    && chown -R django:django /web_server_logs \
    && chmod -R o+r /web_server_logs

# Change the directories into volumes
VOLUME /static_files /media_files /web_server_logs

# Copy the supervisord.conf file over to the container
COPY ./supervisord.conf ./supervisord.conf

# Copy the gunicorn_config.py file over to the container
COPY ./gunicorn_config.py ./gunicorn_config.py

# Define environment variables
ENV PYTHONPATH="/omniport:/omniport/core:/omniport/services:/omniport/apps"
