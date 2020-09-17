#!/bin/bash

set -e # stop script execution on failure

## -------
# Globals variables
JSON_FILE="services.prod.json"                                                  # Insert name of the json services file
AZURE_CONTAINER_REGISTRY_NAME="drivehub"                                        # Insert azure conatiner registry name
AZURE_TEAM_NAME="meateam"                                                       # Insert azure team
AZURE_LOGIN_SERVER="$AZURE_CONTAINER_REGISTRY_NAME.azurecr.io/$AZURE_TEAM_NAME" # Insert azure login server

## -------
# Azure Functions
azure_check_tag_exists () {
    echo "Check if image: $AZURE_TEAM_NAME/$1:$2 exists on Azure acr" 
    az acr repository show -n $AZURE_CONTAINER_REGISTRY_NAME --image $AZURE_TEAM_NAME/$1:$2 > /dev/null
}

## -------
# Git Functions
git_pull_all_services () {
    echo "Git pull submodules" 
    git pull --recurse-submodules
}

check_if_tag_exists () {
    echo "Check if tag $2, exists in Git repository $1" 
    if (GIT_DIR=./$1/.git git rev-parse $2 > /dev/null); then
        echo "Git tag exist"
    else 
        echo "Git tag doesnt exists for repo $1:$2"
        exit
    fi
}

## -------
# 1. Get git submodules
git_pull_all_services

## -------
# 2. Login to azure and set the azure conatiner registry
echo "Logging Into Azure"
az login
echo "Logging Into Acr"
az acr login --n $AZURE_CONTAINER_REGISTRY_NAME

## -------
# 3. Foreach service in services.json file
for service in $(cat $JSON_FILE | jq -r '.[]| @base64') ; do
    
    # Check if image tag exists on azure 
    service_tag=$(echo "$service" | base64 --decode | jq -r '.tag')
    service_name=$(echo "$service" | base64 --decode | jq -r '.name')

    if (azure_check_tag_exists $service_name $service_tag); then
        echo "Docker image $service_name $service_tag exist"
    else 
        echo "Docker image $service_name $service_tag, not exist"
        check_if_tag_exists
    fi
done
