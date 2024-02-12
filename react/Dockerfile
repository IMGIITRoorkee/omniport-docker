# Use Node from the Debian Linux project
FROM node:lts-stretch-slim

# Add labels for metadata
LABEL maintainer="Dhruv Bhanushali <https://dhruvkb.github.io/>"

# Determines whether to build a production or a development package
ARG IMAGETYPE

# Create a non-root user
RUN groupadd --system react && useradd --system --gid react react

# Work in the root directory of the container
WORKDIR /

# Copy the yarn.lock file over to the container
# This command implies an image rebuild when npm dependencies change
COPY ./package.json ./package.json
COPY ./yarn.lock ./yarn.lock

# Add webpack dependency
RUN yarn global add webpack-dev-server@3.1.14

# Install dependenices from the file yarn.lock
RUN yarn install ${IMAGETYPE}

# Add some terminal jazz
RUN echo "PS1='docker@\$NAME:\w\$ '" >> /etc/bash.bashrc

# Enter the omniport directory
WORKDIR /omniport
