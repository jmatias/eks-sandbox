#!/usr/bin/env bash

SCRIPT_ROOT=$(dirname "${BASH_SOURCE}")/..

$SCRIPT_ROOT/hack/configure.sh


red='\033[91m'
green='\033[0;32m'
purple='\033[0;35m'
coloroff='\033[0m'

function getClusterName() {
  clusterName=$(yq .metadata.name - <$SCRIPT_ROOT/cluster/cluster.yaml)
  clusterName=$(echo "$clusterName" | sed -e 's/^"//' -e 's/"$//')
  echo "$clusterName"
}

function restartDeployment() {
  namespace=$1
  deploymentName=$2
  kubectl rollout restart deployment -n $namespace $deploymentName
  kubectl rollout status deployment -n $namespace $deploymentName
}

function waitForDeployment() {
  set +e
  namespace=$1
  deploymentName=$2

  until kubectl get deployment -n $namespace $deploymentName >/dev/null 2>&1; do
    echo Waiting for $deploymentName ...
    sleep 10
  done

  set -e
  kubectl rollout status deployment -n $namespace $deploymentName
}

function waitForHelmRelease() {
  set +e
  namespace=$1
  releaseName=$2

  until helm status -n $namespace $releaseName >/dev/null 2>&1; do
    echo Waiting for helm release $releaseName ...
    sleep 10
  done

}

function fetchRepoUpdates() {
  git branch --set-upstream-to=origin/master
  git fetch
  git rebase origin/master --autostash
}

function runGreen {
  printf "${green}"
  eval $* | while read line; do
      echo $line
  done
  printf "${coloroff}"
}

function runRed {
  printf "${red}"
  eval $* | while read line; do
      echo $line
  done
  printf "${coloroff}"
}

function installVerticalPodAutoscaler() {
  set +e
  kubectl get deployment -n kube-system vpa-updater >/dev/null 2>&1
  retVal=$?
  if [ $retVal -ne 0 ]; then
    git clone --depth 1 git@github.com:kubernetes/autoscaler.git
    cd autoscaler/vertical-pod-autoscaler/hack
    ./vpa-up.sh
    cd ../../../
    rm -rf autoscaler
  fi
}

function createOrUpdateCluster() {

  eksctl get cluster $(getClusterName) >/dev/null 2>&1
  retVal=$?
  set -e
  if [ $retVal -ne 0 ]; then
    eksctl create cluster --config-file ${SCRIPT_ROOT}/cluster/cluster.yaml
  else

    eksctl create iamserviceaccount --config-file ${SCRIPT_ROOT}/cluster/cluster.yaml --approve --override-existing-serviceaccounts
    eksctl enable repo --config-file ${SCRIPT_ROOT}/cluster/cluster.yaml
    eksctl enable profile --config-file ${SCRIPT_ROOT}/cluster/cluster.yaml
  fi

}

#  `7MMM.     ,MMF'      db      `7MMF'`7MN.   `7MF'
#    MMMb    dPMM       ;MM:       MM    MMN.    M
#    M YM   ,M MM      ,V^MM.      MM    M YMb   M
#    M  Mb  M' MM     ,M  `MM      MM    M  `MN. M
#    M  YM.P'  MM     AbmmmqMA     MM    M   `MM.M
#    M  `YM'   MM    A'     VML    MM    M     YMM
#  .JML. `'  .JMML..AMA.   .AMMA..JMML..JML.    YM

if [[ -z "${GITHUB_TOKEN}" ]]; then
  echo "Environment variable GITHUB_TOKEN must be set."
  exit 1
fi



createOrUpdateCluster

fetchRepoUpdates

installVerticalPodAutoscaler

runGreen kubectl apply -f ${SCRIPT_ROOT}/base/namespaces

set -e
runGreen helm upgrade -i helm-operator-ingress fluxcd/helm-operator --set helm.versions=v3 --namespace flux --set workers=40 --set allowNamespace=ingress-nginx
runGreen kubectl apply -f ${SCRIPT_ROOT}/base/releases/ingress-nginx
runRed waitForHelmRelease ingress-nginx external-ingress
runRed waitForDeployment ingress-nginx external-ingress-nginx-ingress-controller

runGreen helm upgrade -i helm-operator-secrets fluxcd/helm-operator --set helm.versions=v3 --namespace flux --set workers=40 --set allowNamespace=external-secrets
runGreen kubectl apply -f ${SCRIPT_ROOT}/base/releases/external-secrets
runRed waitForHelmRelease external-secrets external-secrets
runRed waitForDeployment external-secrets external-secrets-kubernetes-external-secrets

runGreen helm upgrade -i helm-operator-chartmuseum fluxcd/helm-operator --set helm.versions=v3 --namespace flux --set workers=40 --set allowNamespace=chartmuseum
runGreen kubectl apply -f ${SCRIPT_ROOT}/base/releases/chartmuseum
runRed waitForHelmRelease chartmuseum chartmuseum
runRed waitForDeployment chartmuseum chartmuseum-chartmuseum

helm delete -n flux helm-operator-chart-museum
helm delete -n flux helm-operator-secrets
helm delete -n flux helm-operator-ingress

kubectl get hr -A

kubectl get hr -A | grep -vi NAMESPACE | grep -E '(failed)' | awk '{printf "kubectl delete hr -n %s %s\n",$1,$2}' | xargs -I{} -t bash -c '{}'
runRed restartDeployment flux helm-operator-private
kubectl get hr -A
