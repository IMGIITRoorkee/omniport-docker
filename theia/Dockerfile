# Use Node from the Debian Linux project
FROM node:8-stretch

# Add labels for metadata
LABEL maintainer="Dhruv Bhanushali <https://dhruvkb.github.io/>"

# Install dependencies
RUN apt-get update \
    && apt-get install -y python3 python3-dev python3-pip \
    && apt-get clean && rm -rf /var/cache/apt/* && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*

# Install Python packages
RUN pip3 install \
    python-language-server \
    flake8 \
    autopep8

# The remaining portion was mindlessly copied from theia-python-docker
WORKDIR /home/theia
ADD ./package.json ./package.json
ARG GITHUB_TOKEN
RUN yarn --cache-folder ./ycache && rm -rf ./ycache
RUN yarn theia build
EXPOSE 3000
ENV SHELL /bin/bash
ENTRYPOINT [ "yarn", "theia", "start", "/home/project", "--hostname=0.0.0.0" ]