#!/bin/sh

# Copy the package.json file from the codebase into the React Docker folder
cp codebase/omniport-frontend/package.json react/

# Enter the React Docker folder
cd react/

# Build the container from the React folder and tag it
TIMESTAMP=$(date +"%s")
docker build --tag omniport-react:${TIMESTAMP} --tag omniport-react:latest .

# Remove the package.json file after it has served its purpose
rm package.json