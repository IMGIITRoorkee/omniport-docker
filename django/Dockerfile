# Use Python, unfortunately not from the Alpine Linux project
# This is because of a problem in compiling C code when using pip install
FROM python:slim

# Add labels for metadata
LABEL maintainer="Dhruv Bhanushali <https://dhruvkb.github.io/>"

# Expose port 8000 on which Gunicorn serves the Django application
EXPOSE 8000

# Define environment variables
ENV PYTHONPATH="/omniport:/omniport/apps"

# Work in the root directory of the container
WORKDIR /

# Copy the requirements.txt file over to the container
# This command implies an image rebuild when requirements.txt changes
COPY ./omniport/requirements.txt ./requirements.txt

# Update pip to the latest version
RUN ["pip", "install", "--upgrade", "pip"]

# Install packages listed in the requirements.txt file
RUN ["pip", "install", "--requirement", "requirements.txt"]
