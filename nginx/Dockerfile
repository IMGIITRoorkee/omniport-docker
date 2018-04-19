# Use NGINX from the Alpine Linux project
FROM nginx:alpine

# Add labels for metadata
LABEL maintainer="Dhruv Bhanushali <https://dhruvkb.github.io/>"

# Change the working directory
WORKDIR /etc/nginx

# Remove the default welcome message by NGINX
RUN rm -f ./conf.d/default.conf

# Load the configurations from the supplied conf.d directory in its place
# There should be as many .conf files as the number of sites you want to run
ADD ./nginx/conf.d ./conf.d
