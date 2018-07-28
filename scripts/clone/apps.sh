#!/bin/bash

urlencode() {
    # urlencode <string>
    
    old_lc_collate=$LC_COLLATE
    
    LC_COLLATE=C
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
    
    LC_COLLATE=$old_lc_collate
}

read -p "GitHub username: " USERNAME
read -s -p "GitHub password: " PASSWORD
PASSWORD=$(urlencode $PASSWORD)
echo

cd codebase/omniport-backend/omniport/apps

printf "Cloning: Omniport Functionality... "
cd apps/
git clone https://$USERNAME:$PASSWORD@github.com/IMGIITRoorkee/omniport-functionality.git functionality &> /dev/null
cd ..
printf "done\n"
