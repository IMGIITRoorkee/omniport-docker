#!/bin/bash

# Reset the codebase/ directory and enter it
if [[ -d "codebase" ]]; then
    rm -rf codebase
fi
mkdir codebase

# Clone the backend
printf "Cloning the backend\n"
bash ./scripts/clone/backend.sh

# Clone the frontend
printf "Cloning the frontend\n"
bash ./scripts/clone/frontend.sh
