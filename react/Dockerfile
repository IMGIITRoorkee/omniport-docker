# Use Node from the Debian Linux project
FROM node:8-stretch

# Add labels for metadata
LABEL maintainer="Gaurav Kumar <https://gaurav9825.github.io/>"

# Work in the root directory of the container
WORKDIR /

# Copy the package.json file over to the container
# This command implies an image rebuild when package.json changes
COPY ./package.json ./package.json

# Install npm packages
RUN npm install --global npm \
    && npm install --global