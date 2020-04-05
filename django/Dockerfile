# Use Python from the Debian Linux project
FROM python:slim-stretch

# Add labels for metadata
LABEL maintainer="Dhruv Bhanushali <https://dhruvkb.github.io/>"

# Determines whether to build a production or a development package
ARG IMAGETYPE

# Create a non-root user
RUN groupadd --system django && useradd --system --gid django django

# Install dependencies
RUN echo 'deb [ trusted=yes ] http://www.deb-multimedia.org stretch main non-free' >> /etc/apt/sources.list

RUN apt-get update \
    && apt-get install -y \ 
    gcc deb-multimedia-keyring \
    && rm -rf /var/lib/apt/lists/*

# Install ffmpeg for video compression
RUN apt-get update && \
    apt-get -y install ffmpeg && \
    rm -rf /var/lib/apt/lists/*

# Install pip packages
RUN pip install --upgrade pip \
    && pip install --upgrade setuptools \
    && pip install --upgrade pipenv \
    && pip install --upgrade supervisor

# Work in the root directory of the container
WORKDIR /

# Copy the file Pipfile.lock over to the container
# This command implies an image rebuild when PyPI requirements change
COPY ./Pipfile ./Pipfile
COPY ./Pipfile.lock ./Pipfile.lock

# Install dependencies from the file Pipfile.lock
# Depending on build args, dev packages may not be installed
RUN pipenv install --deploy --system ${IMAGETYPE}

# Create the static files volume as a directory
RUN mkdir -p /static_files \
    && chown django:django /static_files \
    && chmod -R o+r /static_files

# Create the media files volume as a directory
RUN mkdir -p /media_files \
    && chown -R django:django /media_files \
    && chmod -R o+r /media_files

# Create the personal files volume as a directory
RUN mkdir -p /personal_files \
    && chown -R django:django /personal_files \
    && chmod -R o+r /personal_files

# Create the supervisor configuration files volume as a directory
RUN mkdir -p /supervisor.d \
    && chown -R django:django /supervisor.d \
    && chmod -R o+r /supervisor.d

# Create the web server logs volume as a directory
RUN mkdir -p /web_server_logs/supervisord_logs  \
    && mkdir -p /web_server_logs/gunicorn_logs \
    && mkdir -p /web_server_logs/daphne_logs \
    && mkdir -p /web_server_logs/server_logs \
    && chown -R django:django /web_server_logs \
    && chmod -R o+r /web_server_logs

# Create the history volume as a directory
RUN mkdir -p /.history \
    && chown django:django /.history \
    && chmod -R o+r /.history

# Change the directories into volumes
VOLUME /static_files /media_files /personal_files /web_server_logs /supervisor.d /.history
# Copy the supervisord.conf file over to the container
COPY ./supervisord.conf ./supervisord.conf

# Copy the gunicorn_config.py file over to the container
COPY ./gunicorn_config.py ./gunicorn_config.py

# Grant read rights to supervisord.conf and gunicorn_config.py
RUN chown django:django ./supervisord.conf \
    && chown django:django ./gunicorn_config.py

# Define environment variables
ENV PYTHONPATH="/omniport:/omniport/core:/omniport/services:/omniport/apps"
ENV HISTFILE="/.history/.bash_history"
ENV IPYTHONDIR="/.history/.ipython/"

# Add some terminal jazz
RUN echo "PS1='docker@\$NAME:\w\$ '" >> /etc/bash.bashrc

# Enter the omniport directory
WORKDIR /omniport
