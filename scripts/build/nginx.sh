#!/bin/bash

# Enter the NGINX Docker folder
cd nginx/

read -p "Rebuild NGINX .conf files? (y/N): " REBUILD
if [ $REBUILD == 'Y' -o $REBUILD == 'y' ]; then
    read -p "Enter the intranet-side domain as 'omniport.intranet': " INTRANET_DOMAIN
    read -p "Enter the Internet-side domain as 'omniport.internet': " INTERNET_DOMAIN

    read -p "Enable HTTPS? [y/N]: " HTTPS

    if [ $HTTPS == 'Y' -o $HTTPS == 'y' ]; then
        MAIN_PORT='443 ssl'   # 'ssl' is essential here
        REDIRECT_INTRANET='include conf\.d\/includes\/01-http_redirect\.conf;'
        REDIRECT_INTERNET='include conf\.d\/includes\/02-http_redirect\.conf;'
        ENABLE_SSL='include conf\.d\/includes\/ssl\.conf;'
    else
        MAIN_PORT='80'
        REDIRECT_INTRANET=''  # Leaves out the include directives
        REDIRECT_INTERNET=''  # Leaves out the include directives
        ENABLE_SSL=''         # Leaves out the include directives
    fi

    # Enter conf.d/ inside the NGINX Docker folder
    cd conf.d/

    # Remove pre-existing .conf files
    rm 01-intranet.conf 02-internet.conf
    rm includes/01-http_redirect.conf includes/02-http_redirect.conf

    # Perform text substitution to generate the new .conf files
    printf "Writing intranet .conf file... "
    cp stencils/01-intranet.conf ./01-intranet.conf
    sed -i "s/\[\[intranet_domain\]\]/${INTRANET_DOMAIN}/g" 01-intranet.conf
    sed -i "s/\[\[main_port\]\]/${MAIN_PORT}/g" 01-intranet.conf
    sed -i "s/\[\[redirect\]\]/${REDIRECT_INTRANET}/g" 01-intranet.conf
    sed -i "s/\[\[enable_ssl\]\]/${ENABLE_SSL}/g" 01-intranet.conf
    printf "done\n"

    printf "Writing intranet redirect file... "
    cp stencils/01-http_redirect.conf ./includes/01-http_redirect.conf
    sed -i "s/\[\[intranet_domain\]\]/${INTRANET_DOMAIN}/g" ./includes/01-http_redirect.conf
    printf "done\n"

    printf "Writing Internet .conf file... "
    cp stencils/02-internet.conf ./02-internet.conf
    sed -i "s/\[\[internet_domain\]\]/${INTERNET_DOMAIN}/g" 02-internet.conf
    sed -i "s/\[\[main_port\]\]/${MAIN_PORT}/g" 02-internet.conf
    sed -i "s/\[\[redirect\]\]/${REDIRECT_INTERNET}/g" 02-internet.conf
    sed -i "s/\[\[enable_ssl\]\]/${ENABLE_SSL}/g" 02-internet.conf
    printf "done\n"

    printf "Writing Internet redirect file... "
    cp stencils/02-http_redirect.conf ./includes/02-http_redirect.conf
    sed -i "s/\[\[internet_domain\]\]/${INTERNET_DOMAIN}/g" ./includes/02-http_redirect.conf
    printf "done\n"

    # Get back out
    cd ..
fi

# Build the container from the nginx folder and tag it
TIMESTAMP=$(date +"%s")

docker build \
    --tag omniport-nginx:${TIMESTAMP} \
    --tag omniport-nginx:latest \
    .

# Remove the .conf files after they have served their purpose
rm conf.d/01-intranet.conf
rm conf.d/02-internet.conf
rm conf.d/includes/01-http_redirect.conf
rm conf.d/includes/02-http_redirect.conf
