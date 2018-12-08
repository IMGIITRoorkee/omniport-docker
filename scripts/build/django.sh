#!/bin/bash

# Copy the prod-requirements.txt file from the codebase into the Django Docker folder
cp codebase/omniport-backend/Pipfile      django/
cp codebase/omniport-backend/Pipfile.lock django/

read -p "Add PyPI dependencies for developer tools? (y/N): " DEV_TOOLS
if [ $DEV_TOOLS == 'Y' -o $DEV_TOOLS == 'y' ]; then
    # Set the build argument IMAGETYPE to --dev
    IMAGETYPE='--dev'

    # Assign a tag of dev-latest for usecases that mandate development
    TAG='dev-latest'
else
    # Set the build argument IMAGETYPE to blank
    IMAGETYPE=''

    # Assign a tag of prod-latest for usecases that mandate production
    TAG='prod-latest'
fi

# Enter the Django Docker folder
cd django/

# Build the container from the Django folder and tag it
TIMESTAMP=$(date +"%s")

docker build \
    --build-arg IMAGETYPE=${IMAGETYPE} \
    --tag omniport-django:${TIMESTAMP} \
    --tag omniport-django:${TAG} \
    --tag omniport-django:latest \
    .

# Remove the requirement files after they have served their purpose
rm Pipfile
rm Pipfile.lock