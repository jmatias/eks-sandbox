#!/usr/bin/env bash

SCRIPT_ROOT=$(dirname "${BASH_SOURCE}")/..

command -v eksctl >/dev/null 2>&1
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

command -v fluxctl >/dev/null 2>&1
retVal=$?
if [ $retVal -ne 0 ]; then

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then

    sudo wget "https://github.com/fluxcd/flux/releases/download/1.20.0/fluxctl_linux_amd64" -O /usr/local/bin/fluxctl
    sudo chmod +x /usr/local/bin/fluxctl

  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "sdsd"
  else
    echo "$OSTYPE" is not supported at this time.
  fi

fi

command -v yq > /dev/null 2>&1
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
