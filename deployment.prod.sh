#!/bin/bash

set -e # stop script execution on failure
# set -x # debug option - show runing commands

## --------------------------------------------------------------------------------------------------------
# Globals variables
JSON_FILE="services.prod.json"                                                  # Insert name of the json services file
AZURE_CONTAINER_REGISTRY_NAME="drivehub"                                        # Insert azure conatiner registry name
AZURE_TEAM_NAME="meateam"                                                       # Insert azure team
AZURE_LOGIN_SERVER="$AZURE_CONTAINER_REGISTRY_NAME.azurecr.io/$AZURE_TEAM_NAME" # Insert azure login server
DATE=$(date +"%d.%m")                                                           # The date of the execution
HALBANA_FOLDER="../halbana-$DATE"
RED=`tput setaf 1`
NC=`tput sgr0` # No Color

## --------------------------------------------------------------------------------------------------------
# Azure Functions
azure_check_tag_exists () {
    # arguments: $1 - service_name , $2 - service_tag
    echo "Check if image: $AZURE_TEAM_NAME/$1:$2 exists on Azure acr" 
    az acr repository show -n $AZURE_CONTAINER_REGISTRY_NAME --image $AZURE_TEAM_NAME/$1:$2 > /dev/null
}

## -------
# Git Functions
git_pull_all_services () {
    echo "Git pull submodules" 
    git pull --recurse-submodules
}

git_check_tag_exists () {
    # arguments: $1 - repo_name , $2 - repo_tag
    echo "Check if tag $2, exists in Git repository $1" 
    if (GIT_DIR=./$1/.git git rev-parse $2 > /dev/null 2>&1); then
        :
    else 
        echo "${RED} Git tag $2 doesnt exist for repo $1"
        exit
    fi
}

git_checkout_tag() {
    # arguments: $1 - repo_name , $2 - repo_tag
    echo "Checkout tag $2, in Git repository $1" 
    if (GIT_DIR=./$1/.git git checkout tags/$2 > /dev/null 2>&1); then
        :
    else 
        echo "${RED} Cant checkout git repostiory $1 with tag $2"
        exit
    fi
}

## -------
# Docker Functions
docker_build_and_push_image() {
    # arguments: $1 - service_name , $2 - service_tag
    docker build ./$1/. -t $AZURE_LOGIN_SERVER/$1:$2 --no-cache 
    docker push $AZURE_LOGIN_SERVER/$1:$2
}

docker_pull_and_save_image(){
    # arguments: $1 - service_name , $2 - service_tag
    if [[ "$(docker images -q $1:$2 2> /dev/null)" == "" ]]; then
        echo "pull image $1:$2..."
        docker pull $AZURE_LOGIN_SERVER/$1:$2
    fi


    echo "saving image $1:$2..."
    docker save $AZURE_LOGIN_SERVER/$1:$2 -o $1-$DATE.tar
    mv $1-$DATE.tar $HALBANA_FOLDER
}

## -------
# Helm Functions
helm_check_tag_exists() {
    # arguments: $1 - chart_name , $2 - chart_image_tag
    helm show values z-helm/$1 | grep tag | grep $2 
}

helm_change_tag() {
    # arguments: $1 - chart_name , $2 - chart_image_tag
    if [[ $(cat z-helm/$1/values.yaml | sed -n 's/.*\(tag\).*/\1/p') == "" ]]; then
        echo "${RED} Cant found tag attribute in helm chart $1 ${NC}"
    else 
        echo "Changing the image tag for helm chart $1 to tag $2"
        sed -r "s/^(\s*tag\s*:\s*).*/\1\"${2}\"/" -i z-helm/$1/values.yaml 
    fi
}

## --------------------------------------------------------------------------------------------------------
# 1. Get script flags
ZIP=
HELM=
for arg in "$@"; do
    case $arg in
        -z | --zip) ZIP=true;;
        -h | --helm) HELM=true;;
    esac
done

## -------
# 2. Get git submodules
git_pull_all_services

## -------
# 3. Foreach service in services.json file - Check if git tag exist
for service in $(cat $JSON_FILE | jq -r '.[]| @base64') ; do
    
    # Get service name and tag from json file
    service_tag=$(echo "$service" | base64 --decode | jq -r '.tag')
    service_name=$(echo "$service" | base64 --decode | jq -r '.name')

    git_check_tag_exists $service_name $service_tag
done


## -------
# 4. Create halbana folder 
if [[ $ZIP ]]; then
    mkdir $HALBANA_FOLDER 
fi

## -------
# 5. Login to azure and set the azure conatiner registry
echo "Logging Into Azure"
az login
echo "Logging Into Acr"
az acr login --n $AZURE_CONTAINER_REGISTRY_NAME


## -------
# 6. Foreach service in services.json file - implement
for service in $(cat $JSON_FILE | jq -r '.[]| @base64') ; do
    
    # Get service name and tag from json file
    service_tag=$(echo "$service" | base64 --decode | jq -r '.tag')
    service_name=$(echo "$service" | base64 --decode | jq -r '.name')

    # Check if the tag exists in acr
    # If not, check if the tag exists on git, build an image and upload to acr
    if (azure_check_tag_exists $service_name $service_tag); then
        echo "Image: $service_name:$service_tag exists on Azure acr" 
    else 
        echo "Image $service_name $service_tag, does not exist on acr"
        git_checkout_tag $service_name $service_tag
        docker_build_and_push_image $service_name $service_tag
    fi

    # If this flag mentioned, Check the tags of the helm charts 
    if [[ $HELM ]]; then
         echo "Check if tag $service_tag exists in helm chart file $service_name..."

        # Change the helm chart tag image if not updated
        if [ -z "$(helm_check_tag_exists $service_name $service_tag)" ]; then

            helm_change_tag $service_name $service_tag
        fi
    fi

    if [[ $ZIP ]]; then
        docker_pull_and_save_image $service_name $service_tag
    fi
done

## -------
# 7. Zip halbana folder 
if [[ $ZIP ]]; then
    7z a $HALBANA_FOLDER.7z $HALBANA_FOLDER
    rm -r $HALBANA_FOLDER
fi
