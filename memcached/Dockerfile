# Use Memcached from the Debian Linux project
FROM memcached:latest

# Need to undo the misdeeds of Memcached developers
USER root

# Add labels for metadata
LABEL maintainer="Dhruv Bhanushali <https://dhruvkb.github.io/>"

# Install dependencies
RUN apt-get update \
    && apt-get install -y netcat \
    && rm -rf /var/lib/apt/lists/*

# Undo our undoing of Memcache's misdeeds, just in case they are important
USER memcache