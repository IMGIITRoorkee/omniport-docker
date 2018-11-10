#!/bin/sh

# Copy the prod-requirements.txt file from the codebase into the Django Docker folder
cp codebase/omniport-backend/omniport/prod-requirements.txt django/

read -p "Add PyPI dependencies for developer tools? (y/N): " DEV_TOOLS
if [ $DEV_TOOLS == 'Y' -o $DEV_TOOLS == 'y' ]; then
    # Copy the dev-requirements.txt file from the codebase into the Django Docker folder
    cp codebase/omniport-backend/omniport/dev-requirements.txt django/
else
    # Ensure a blank dev-requirements.txt file exists
    echo '' > django/dev-requirements.txt
fi

# Enter the Django Docker folder
cd django/

# Build the container from the Django folder and tag it
TIMESTAMP=$(date +"%s")
docker build --tag omniport-django:${TIMESTAMP} --tag omniport-django:latest .

# Remove the requirement files after they have served their purpose
rm prod-requirements.txt dev-requirements.txt