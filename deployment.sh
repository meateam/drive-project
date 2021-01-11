#!/bin/bash

set -e # stop script execution on failure

# set -x # debug option - show runing commands


## --------------------------------------------------------------------------------------------------------
# Globals variables
AZURE_CONTAINER_REGISTRY_NAME="drivehub"                                        # Insert azure conatiner registry name
AZURE_TEAM_NAME="meateam"                                                       # Insert azure team
AZURE_LOGIN_SERVER="$AZURE_CONTAINER_REGISTRY_NAME.azurecr.io/$AZURE_TEAM_NAME" # Insert azure login server
DATE=$(date +"%d.%m")                                                           # The date of the execution
HALBANA_FOLDER="../halbana-$DATE"                                               # The name of the halbana folder

. deploy.env # load script env 

## --------------------------------------------------------------------------------------------------------
# String formatters
if [[ -t 1 ]]; then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi

tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_green="$(tty_mkbold 32)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"


msg() {
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$1"
}

warn() {
  printf "${tty_red}Warning${tty_reset}: %s\n" "$1"
}

success() {
  printf "${tty_green}%s${tty_reset} \n" "$1"
}


abort() {
  printf "${tty_red}%s\n${tty_reset}" "$1"
  exit 1
}


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
    msg "Git pull submodules" 

    git submodule update --remote --merge
}

git_check_tag_exists () {
    # arguments: $1 - repo_name , $2 - repo_tag
    echo "Check if tag $2, exists in Git repository $1" 
    if (GIT_DIR=./$1/.git git rev-parse $2 > /dev/null 2>&1); then
        :
    else 
        abort "Git tag $2 doesnt exist for repo $1"
    fi
}

git_checkout_tag() {
    # arguments: $1 - repo_name , $2 - repo_tag
    echo "Checkout tag $2, in Git repository $1" 
    if (GIT_DIR=./$1/.git git checkout tags/$2 > /dev/null 2>&1); then
        :
    else 
        abort "Cant checkout git repostiory $1 with tag $2"
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
    helm inspect values z-helm/$1 | grep tag | grep $2 
}

helm_change_tag() {
    # arguments: $1 - chart_name , $2 - chart_image_tag
    if [[ $(cat z-helm/$1/values.yaml | sed -n 's/.*\(tag\).*/\1/p') == "" ]]; then
        warn "${RED} Cant found tag attribute in helm chart $1 ${NC}"
    else 
        echo "Changing the image tag for helm chart $1 to tag $2"
        sed -r "s/^(\s*tag\s*:\s*).*/\1\"${2}\"/" -i z-helm/$1/values.yaml 
    fi
}


## --------------------------------------------------------------------------------------------------------
# 1. Get script flags
ZIP=false
HELM=false
KBS=false
GIT=false
FORCE=false
for arg in "$@"; do
    case $arg in
        -z | --zip) ZIP=true;;
        -h | --helm) HELM=true;;
        -k | --kubectl) KBS=true;;
        -g | --git) GIT=true;;
        -f | --force) FORCE=true;;
    esac
done

# -------
if ($GIT); then
    # 2. Get git submodules
    git_pull_all_services

    ## -------
    # 3. Foreach service in services.json file - Check if git tag exist
    msg "Check if services tags exist in git"
    for service in $(cat $JSON_FILE | jq -r '.[]| @base64') ; do
        
        # Get service name and tag from json file
        service_tag=$(echo "$service" | base64 --decode | jq -r '.tag')
        service_name=$(echo "$service" | base64 --decode | jq -r '.name')

        git_check_tag_exists $service_name $service_tag
    done
fi


## -------
# 4. Create halbana folder 
if ($ZIP); then
    msg "Create halbana folder with the name $HALBANA_FOLDER"
    mkdir $HALBANA_FOLDER 
fi

## -------
# 5. Login to azure and set the azure conatiner registry
msg "Logging Into Azure"
az login
msg "Logging Into Acr"
az acr login --n $AZURE_CONTAINER_REGISTRY_NAME


## -------
# 6. Foreach service in services.json file - implement
for service in $(cat $JSON_FILE | jq -r '.[]| @base64') ; do
    # Get service name and tag from json file
    service_tag=$(echo "$service" | base64 --decode | jq -r '.tag')
    service_name=$(echo "$service" | base64 --decode | jq -r '.name')

    msg "Service: $service_name"

    # Check if the tag exists in acr
    # If not, check if the tag exists on git, build an image and upload to acr
    if (azure_check_tag_exists $service_name $service_tag); then
        echo "Image: $service_name:$service_tag exists on Azure acr" 

        if ($FORCE); then
            docker_build_and_push_image $service_name $service_tag
        fi
    else 
        warn "Image $service_name $service_tag, does not exist on acr"
        if ($GIT); then
            git_check_tag_exists $service_name $service_tag
            git_checkout_tag $service_name $service_tag
        fi
        docker_build_and_push_image $service_name $service_tag
    fi

    # If this flag mentioned, Check the tags of the helm charts 
    if ($HELM); then
         echo "Check if tag $service_tag exists in helm chart file $service_name..."

        # Change the helm chart tag image if not updated
        if [ -z "$(helm_check_tag_exists $service_name $service_tag)" ]; then
            helm_change_tag $service_name $service_tag
        fi
    fi

    if ($ZIP); then
        docker_pull_and_save_image $service_name $service_tag
    fi
done


## -------
# 7. Update helm dependencies 
if ($HELM && $HELM_DEPENDENCIES); then
    msg "Update helm charts dependencies"
    z-helm/helm-dep-up-umbrella.sh z-helm/helm-chart/
fi

## -------
# 8. Zip halbana folder 
if ($ZIP); then
    msg "Zip halbana folder"
    7z a $HALBANA_FOLDER.7z $HALBANA_FOLDER
    rm -r $HALBANA_FOLDER
fi

## -------
# 9. Deploy kubernetes
if ($KBS); then
    msg "Deploy kubernetes"
    
    # Check if an deployment name with the same name exist to another namespace
    if [[ $(helm list $HELM_DEPLOY_NAME | awk -v namespace="$KBS_NAMESPACE" '$11 != namespace {print $11}') ]]; then
        abort "found an existing deployment with the same name: $HELM_DEPLOY_NAME, at namespace:$KBS_NAMESPACE"
    fi

    if [[ $(helm list --namespace=$KBS_NAMESPACE $HELM_DEPLOY_NAME) ]]; then        
        msg "delete helm purge existing deployment $HELM_DEPLOY_NAME"
        helm del --purge $HELM_DEPLOY_NAME
    fi

    msg "helm install $HELM_DEPLOY_NAME"
    helm install z-helm/helm-chart/ --name=$HELM_DEPLOY_NAME --namespace=$KBS_NAMESPACE \
    --set global.ingress.hosts[0]=$KBS_DNS.northeurope.cloudapp.azure.com
fi

success "DONE..."
