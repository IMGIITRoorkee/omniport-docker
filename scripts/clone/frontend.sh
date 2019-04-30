#!/bin/bash

# Import the utility functions
source ./scripts/clone/utils.sh

# Check if codebase/ directory exists and enter it
if [[ ! -d "codebase" ]]; then
    mkdir codebase/
fi
cd codebase/

# Reset the omniport-frontend/ directory and enter it
if [[ -d "omniport\-frontend" ]]; then
    rm -rf omniport-frontend
fi
clonerepo   "Frontend core" "omniport-frontend" "omniport-frontend"
cd omniport-frontend/

# Pass the cloning to the frontend's clone scripts
bash ./scripts/clone/everything.sh
