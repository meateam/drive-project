#!/bin/bash

path=$1
cd $path

updateSubDir() {
  subDir=$1
  echo "Updating dependencies in "$(pwd)"/"$subDir" ..."
  rm -rf "$(pwd)"/"$subDir"/charts
  helm dep up --skip-refresh "$(pwd)"/"$subDir"
  echo
}

changedHelmDirs=$(git diff --name-only | xargs -L1 dirname | uniq)
changedHelmDirs=${changedHelmDirs//z-helm/}
if [ -e requirements.yaml ]; then
  for subDir in $(awk -F'repository: file://' '{print $2}' requirements.yaml)
  do
    parsedSubDir=${subDir//../}
    if [[ $changedHelmDirs == *$parsedSubDir* ]] || [[ -z $changedHelmDirs ]]; then
      updateSubDir $subDir
    fi
  done
  updateSubDir "."
fi
