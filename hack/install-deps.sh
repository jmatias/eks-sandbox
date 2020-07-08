#!/usr/bin/env bash

SCRIPT_ROOT=$(dirname "${BASH_SOURCE}")/..

eksctlOutput=$(which eksctl)
retVal=$?
if [ $retVal -ne 0 ]; then

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then

          curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
          sudo mv /tmp/eksctl /usr/local/bin

  elif [[ "$OSTYPE" == "darwin"* ]]; then
          /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
          brew tap weaveworks/tap
          brew install weaveworks/tap/eksctl
          brew upgrade eksctl && brew link --overwrite eksctl
  else
         echo "$OSTYPE" is not supported at this time.
  fi

fi

yqOutput=$(which yq)
retVal=$?

if [ $retVal -ne 0 ]; then

  python3 -m venv $SCRIPT_ROOT/.venv
  source $SCRIPT_ROOT/.venv/bin/activate

  output=$(pip install -r $SCRIPT_ROOT/hack/requirements.txt 2>&1)
  retVal=$?
  if [ $retVal -ne 0 ]; then
    echo $output
    exit $retVal
  fi


fi




