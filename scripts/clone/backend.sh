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
if [[ -d "omniport\-backend" ]]; then
    rm -rf omniport-backend
fi
clonerepo   "Backend core" "omniport-backend"                 "omniport-backend"
cd omniport-backend/

cd omniport/

# Clone shell with the consent of the user
read -p "Setup the shell for IIT Roorkee? (y/N): " CLONE_SHELL
if [ "$CLONE_SHELL" == 'y' -o "$CLONE_SHELL" == 'Y' ]; then
    clonerepo   "Shell"     "omniport-shell"                    "shell"
else
    printf "Skipping Shell\n"
fi

# Clone the services in the services/ directory
cd services/
clonerepo   "Apps"          "omniport-service-apps"             "apps"
clonerepo   "Categories"    "omniport-service-categories"       "categories"
clonerepo   "Comments"      "omniport-service-comments"         "comments"
clonerepo   "Developer"     "omniport-service-developer"        "developer"
clonerepo   "Feed"          "omniport-service-feed"             "feed"
clonerepo   "GIF (huge)"    "omniport-service-gif"              "gif"
clonerepo   "Groups"        "omniport-service-groups"           "groups"
clonerepo   "Helpcentre"    "omniport-service-helpcentre"       "helpcentre"
clonerepo   "Links"         "omniport-service-links"            "links"
clonerepo   "Notifications" "omniport-service-notifications"    "notifications"
clonerepo   "Settings"      "omniport-service-settings"         "settings"
clonerepo   "Yellow pages"  "omniport-service-yellow-pages"     "yellow_pages"

# Escape back to the root directory
cd ../../../../
