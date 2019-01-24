#!/bin/bash

# Import the utility functions
source ./scripts/clone/utils.sh

# Ask the user for their GitHub credentials
read -p "GitHub username: " USERNAME
read -s -p "GitHub password: " PASSWORD
PASSWORD=$(urlencode ${PASSWORD})
echo

# Reset the codebase/ directory and enter it
if [[ -d "codebase" ]]; then
    rm -rf codebase
fi
mkdir codebase

printf "\nCloning backend\n"
source ./scripts/clone/backend.sh

printf "\nCloning frontend\n"
source ./scripts/clone/frontend.sh
