#!/bin/bash

# Import the utility functions
source ./scripts/clone/utils.sh

# Check if codebase/ directory exists and enter it
if [[ ! -d "codebase" ]]; then
    mkdir codebase/
fi
cd codebase/

# Reset the omniport-backend/ directory and enter it
if [[ -d "omniport\-backend" ]]; then
    rm -rf omniport-backend
fi
clonerepo   "Backend core"  "omniport-backend"  "omniport-backend"
cd omniport-backend/

# Pass the cloning to the backend's clone scripts
bash ./scripts/clone/everything.sh
