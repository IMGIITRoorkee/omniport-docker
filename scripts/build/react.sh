#!/bin/bash

# Copy the yarn.lock file from the codebase into the React Docker folder
cp codebase/omniport-frontend/omniport/package.json react/
cp codebase/omniport-frontend/omniport/yarn.lock    react/

read -p "Add npm dependencies for developer tools? (y/N): " DEV_TOOLS
if [ $DEV_TOOLS == 'Y' -o $DEV_TOOLS == 'y' ]; then
    # Set the build argument IMAGETYPE to blank
    IMAGETYPE=''

    # Assign a tag of dev-latest for usecases that mandate development
    TAG='dev-latest'
else
    # Set the build argument IMAGETYPE to --prod
    IMAGETYPE='--prod'

    # Assign a tag of prod-latest for usecases that mandate production
    TAG='prod-latest'
fi

# Enter the React Docker folder
cd react/

# Build the container from the React folder and tag it
TIMESTAMP=$(date +"%s")

docker build \
    --build-arg IMAGETYPE=${IMAGETYPE} \
    --tag omniport-react:${TIMESTAMP} \
    --tag omniport-react:${TAG} \
    --tag omniport-react:latest \
    .

# Remove the yarn.lock file after it has served its purpose
rm package.json
rm yarn.lock