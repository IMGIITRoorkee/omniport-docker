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

mkdir codebase/
cd codebase/

printf "Cloning: Omniport Backend... "
git clone https://$USERNAME:$PASSWORD@github.com/IMGIITRoorkee/omniport-backend.git omniport-backend &> /dev/null
cd omniport-backend/omniport/
printf "done\n"

read -p "Setup the shell for IIT Roorkee? (Y/n)" CLONE_SHELL

if [ $CLONE_SHELL != 'n' -a $CLONE_SHELL != 'N' ]; then
    printf "Cloning: Omniport Shell (IIT Roorkee)... "
    git clone https://$USERNAME:$PASSWORD@github.com/IMGIITRoorkee/omniport-shell.git shell &> /dev/null
    printf "done\n"
fi

printf "Cloning: Omniport Bootstrap... "
cd services/
git clone https://$USERNAME:$PASSWORD@github.com/IMGIITRoorkee/omniport-bootstrap.git bootstrap &> /dev/null
cd ..
printf "done\n"