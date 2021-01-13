#!/bin/bash

# Enter the NGINX Docker folder
cd nginx/

read -p "Rebuild NGINX .conf files? (y/N): " REBUILD
if [ $REBUILD == 'Y' -o $REBUILD == 'y' ]; then
    read -p "Enter the intranet-side domain as 'omniport.intranet': " INTRANET_DOMAIN
    read -p "Enter the Internet-side domain as 'omniport.internet': " INTERNET_DOMAIN
    read -p "Enter timeout value for intranet server (in seconds) [60]: " INTRANET_TIMEOUT
    INTRANET_TIMEOUT=${INTRANET_TIMEOUT:-60}
    read -p "Enter timeout value for internet server (in seconds) [60]: " INTERNET_TIMEOUT
    INTERNET_TIMEOUT=${INTERNET_TIMEOUT:-60}

    # Choose whether to enable SSL in the NGINX conf
    read -p "Enable HTTPS? [y/N]: " HTTPS
    if [ $HTTPS == 'Y' -o $HTTPS == 'y' ]; then
        MAIN_PORT='443 ssl'   # 'ssl' is essential here
        REDIRECT_INTRANET='include conf\.d\/includes\/01-redirect\.conf;'
        REDIRECT_INTERNET='include conf\.d\/includes\/02-redirect\.conf;'
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
    rm 0*.conf
    rm includes/0*.conf

    # Perform text substitution to generate the new .conf files
    printf "Writing intranet application file... "
    cp stencils/application.conf includes/01-application.conf
    sed -i "s/\[\[side\]\]/intranet/g" includes/01-application.conf
    sed -i "s/\[\[timeout\]\]/${INTRANET_TIMEOUT}/g" includes/01-application.conf
    printf "done\n"

    printf "Writing intranet http_redirect file... "
    cp stencils/redirect.conf includes/01-redirect.conf
    sed -i "s/\[\[domain\]\]/${INTRANET_DOMAIN}/g" includes/01-redirect.conf
    printf "done\n"

    printf "Writing intranet logging file... "
    cp stencils/logging.conf includes/01-logging.conf
    sed -i "s/\[\[side\]\]/intranet/g" includes/01-logging.conf
    printf "done\n"

    printf "Writing intranet upstreams file... "
    cp stencils/upstreams.conf includes/01-upstreams.conf
    sed -i "s/\[\[side\]\]/intranet/g" includes/01-upstreams.conf
    printf "done\n"

    printf "Writing main intranet .conf file... "
    cp stencils/main.conf 01-intranet.conf
    sed -i "s/\[\[side\]\]/intranet/g" 01-intranet.conf
    sed -i "s/\[\[id\]\]/01/g" 01-intranet.conf
    sed -i "s/\[\[redirect\]\]/${REDIRECT_INTRANET}/g" 01-intranet.conf
    sed -i "s/\[\[main_port\]\]/${MAIN_PORT}/g" 01-intranet.conf
    sed -i "s/\[\[domain\]\]/${INTRANET_DOMAIN}/g" 01-intranet.conf
    sed -i "s/\[\[enable_ssl\]\]/${ENABLE_SSL}/g" 01-intranet.conf
    printf "done\n"

    printf "Writing Internet application file... "
    cp stencils/application.conf includes/02-application.conf
    sed -i "s/\[\[side\]\]/internet/g" includes/02-application.conf
    sed -i "s/\[\[timeout\]\]/${INTERNET_TIMEOUT}/g" includes/02-application.conf
    printf "done\n"

    printf "Writing Internet http_redirect file... "
    cp stencils/redirect.conf includes/02-redirect.conf
    sed -i "s/\[\[domain\]\]/${INTERNET_DOMAIN}/g" includes/02-redirect.conf
    printf "done\n"

    printf "Writing Internet logging file... "
    cp stencils/logging.conf includes/02-logging.conf
    sed -i "s/\[\[side\]\]/internet/g" includes/02-logging.conf
    printf "done\n"

    printf "Writing Internet upstreams file... "
    cp stencils/upstreams.conf includes/02-upstreams.conf
    sed -i "s/\[\[side\]\]/internet/g" includes/02-upstreams.conf
    printf "done\n"

    printf "Writing main Internet .conf file... "
    cp stencils/main.conf 02-internet.conf
    sed -i "s/\[\[side\]\]/internet/g" 02-internet.conf
    sed -i "s/\[\[id\]\]/02/g" 02-internet.conf
    sed -i "s/\[\[redirect\]\]/${REDIRECT_INTERNET}/g" 02-internet.conf
    sed -i "s/\[\[main_port\]\]/${MAIN_PORT}/g" 02-internet.conf
    sed -i "s/\[\[domain\]\]/${INTERNET_DOMAIN}/g" 02-internet.conf
    sed -i "s/\[\[enable_ssl\]\]/${ENABLE_SSL}/g" 02-internet.conf
    printf "done\n"

    # Get back out
    cd ..
fi

# Build the container from the NGINX folder and tag it
TIMESTAMP=$(date +"%s")

docker build \
    --tag omniport-nginx:${TIMESTAMP} \
    --tag omniport-nginx:latest \
    .
