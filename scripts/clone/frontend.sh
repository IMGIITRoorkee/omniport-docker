#!/bin/bash

# Import the utility functions
source ./scripts/clone/utils.sh

# Check if the GitHub username and password have been set already
if [ -z "$USERNAME" -o -z "$PASSWORD" ]; then
    read -p "GitHub username: " USERNAME
    read -s -p "GitHub password: " PASSWORD
    PASSWORD=$(urlencode ${PASSWORD})
    echo
fi

# Check if codebase/ directory exists and enter it
if [[ ! -d "codebase" ]]; then
    mkdir codebase/
fi
cd codebase/

# Reset the omniport-frontend/ directory and enter it
if [[ -d "omniport\-frontend" ]]; then
    rm -rf omniport-frontend
fi
clonerepo   "Frontend core" "omniport-frontend"                 "omniport-frontend"
cd omniport-frontend/

# Clone formula_one
cd omniport/
clonerepo   "Formula one"   "omniport-frontend-formula-one"     "formula_one"

# Clone the services in the services/ directory
cd services/
clonerepo   "Apps"          "omniport-frontend-apps"            "apps"
clonerepo   "Auth"          "omniport-frontend-auth"            "auth"
clonerepo   "Developer"     "omniport-frontend-developer"       "developer"
clonerepo   "Feed"          "omniport-frontend-feed"            "feed"
clonerepo   "Groups"        "omniport-frontend-groups"          "groups"
clonerepo   "Helpcentre"    "omniport-frontend-helpcentre"      "helpcentre"
clonerepo   "Links"         "omniport-frontend-links"           "links"
clonerepo   "OAuth"         "omniport-frontend-oauth"           "oauth"
clonerepo   "Settings"      "omniport-frontend-settings"        "settings"
clonerepo   "Terms of use"  "omniport-frontend-terms-of-use"    "terms_of_use"

# Escape back to the root directory
cd ../../../../
