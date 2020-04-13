#!/bin/bash

#Get the base location of omniport frontend
all_base_paths=($(find ${PWD}/../../ -type d -name "omniport-frontend" 2>/dev/null))
base_path=${all_base_paths[0]}

cd ${base_path}

#Utility function to pull a repository
pullrepo(){
    DIRECTORY=$1

    cd ${DIRECTORY}
    url=$(git remote get-url origin)
    if [[ $(git rev-parse --is-inside-work-tree) == 'true' ]]
    then
        echo -e "\e[7;32m$(basename ${url})\e[0m"
        if [ -z "$(git status --untracked-files=no --porcelain)" ]; then 
            git pull --rebase origin master
        else
            echo "UNCOMMITED CHANGES"
            echo -e "\e[1;31mSTASH THE CHANGES IN ${DIRECTORY} and PROCEED? y/Y FOR YES OR n/N FOR NO\e[0m"
            read do_stash
            if [[ ${do_stash} == 'y' || ${do_stash} == 'Y' ]]
            then
                git stash
                git pull --rebase origin master
            else
                echo "Aborted Pulling ${DIRECTORY}"
                printf "\n\n"
                return
            fi
        fi
    fi

    cd ${base_path}

    printf "\n\n"
}

#Pull the backend formula one
formula_one="${base_path}/omniport/formula_one"
pullrepo ${formula_one}

#Pull all the services
services="${base_path}/omniport/services"
cd ${services}
for d in */; do
    service="${services}/${d}"
    pullrepo ${service}
done

#Pull all the apps
apps="${base_path}/omniport/apps"
cd ${apps}
for d in */; do
    app="${apps}/${d}"
    pullrepo ${app}
done
