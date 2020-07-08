#!/usr/bin/env bash

SCRIPT_ROOT=$(dirname "${BASH_SOURCE}")/..

$SCRIPT_ROOT/hack/install-deps.sh

grep '<cluster-name-placeholder>' $SCRIPT_ROOT/cluster/cluster.yaml > /dev/null 2>&1
retVal=$?
if [ $retVal -eq 0 ]; then
  echo -n "Cluster name: "
  read clusterName
  sed -i "s/<cluster-name-placeholder>/$clusterName/g" $SCRIPT_ROOT/cluster/cluster.yaml
fi


grep '<email-placeholder>' $SCRIPT_ROOT/cluster/cluster.yaml > /dev/null 2>&1
retVal=$?
if [ $retVal -eq 0 ]; then
  echo -n "Email address: "
  read email
  sed -i "s/<email-placeholder>/$email/g" $SCRIPT_ROOT/cluster/cluster.yaml
fi

grep '<repo-url-placeholder>' $SCRIPT_ROOT/cluster/cluster.yaml > /dev/null 2>&1
retVal=$?
if [ $retVal -eq 0 ]; then
  repoUrl=$(git remote -v | awk '{print $2}' | head -1)
  repoUrl=$(echo $repoUrl | sed 's/\//\\\//g')
  sed -i "s/<repo-url-placeholder>/$repoUrl/g" $SCRIPT_ROOT/cluster/cluster.yaml
fi
