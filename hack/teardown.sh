#!/usr/bin/env bash

SCRIPT_ROOT=$(dirname "${BASH_SOURCE}")/..

$SCRIPT_ROOT/hack/reset.sh

if [[ -z "${GITHUB_TOKEN}" ]]; then
  echo nope!
  exit 1
fi

clusterName=$(yq .metadata.name - <cluster/cluster.yaml)
clusterName=$(echo "$clusterName" | sed -e 's/^"//' -e 's/"$//')

eksctl get cluster "$clusterName" >/dev/null 2>&1
retVal=$?

set -e

if [ $retVal -eq 0 ]; then
  eksctl delete cluster --name "$clusterName"
fi
