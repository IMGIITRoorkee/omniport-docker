# Use NGINX from the Alpine Linux project
FROM nginx:alpine

# Add labels for metadata
LABEL maintainer="Dhruv Bhanushali <https://dhruvkb.github.io/>"

# Work in the root directory of the container
WORKDIR /

# Create the reverse proxy logs volume as a directory
RUN mkdir -p /reverse_proxy_logs/nginx_logs \
    && chown -R nginx:nginx /reverse_proxy_logs \
    && chmod -R o+r /reverse_proxy_logs

# Change the directories into volumes
VOLUME /reverse_proxy_logs

# Change the working directory
WORKDIR /etc/nginx

# Remove the default welcome message by NGINX
RUN rm -f ./conf.d/default.conf

# Load the configurations from the supplied conf.d directory in its place
# There should be as many .conf files as the number of sites you want to run
ADD ./conf.d ./conf.d
