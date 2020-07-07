#!/usr/bin/env bash


if [[ -z "${GITHUB_TOKEN}" ]]; then
  echo nope!
  exit 1
fi

SCRIPT_ROOT=$(dirname "${BASH_SOURCE}")/..

clusterName=$(yq .metadata.name - < cluster/cluster.yaml)
clusterName=$(echo "$clusterName" | sed -e 's/^"//' -e 's/"$//')

eksctl get cluster "$clusterName"
retVal=$?

set -e

if [ $retVal -eq 0 ]; then
    eksctl delete cluster --name $clusterName
fi


