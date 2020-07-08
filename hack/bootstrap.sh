#!/usr/bin/env bash

SCRIPT_ROOT=$(dirname "${BASH_SOURCE}")/..

$SCRIPT_ROOT/hack/configure.sh

if [[ -z "${GITHUB_TOKEN}" ]]; then
  echo "Environment variable GITHUB_TOKEN must be set."
  exit 1
fi

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

  until helm status -n $namespace $deploymentName >/dev/null 2>&1; do
    echo Waiting for $deploymentName ...
    sleep 10
  done
}

function fetchRepoUpdates() {
  git branch --set-upstream-to=origin/master
  git fetch
  git rebase origin/master --autostash
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

createOrUpdateCluster

fetchRepoUpdates

installVerticalPodAutoscaler

set -e
helm upgrade -i helm-operator-secrets fluxcd/helm-operator --set helm.versions=v3 --namespace flux --set workers=40 --set allowNamespace=external-secrets
helm upgrade -i helm-operator-ingress fluxcd/helm-operator --set helm.versions=v3 --namespace flux --set workers=40 --set allowNamespace=ingress-nginx
kubectl apply -f ${SCRIPT_ROOT}/base/namespaces
kubectl apply -f ${SCRIPT_ROOT}/base/releases/ingress-nginx
kubectl apply -f ${SCRIPT_ROOT}/base/releases/external-secrets


waitForDeployment ingress-nginx external-ingress
set -e
kubectl rollout status deployment -n ingress-nginx external-ingress-nginx-ingress-controller


waitForDeployment external-secrets external-secrets
set -e
kubectl rollout status deployment -n external-secrets external-secrets-kubernetes-external-secrets


helm upgrade -i helm-operator-chartmuseum fluxcd/helm-operator --set helm.versions=v3 --namespace flux --set workers=40 --set allowNamespace=chartmuseum
kubectl apply -f ${SCRIPT_ROOT}/base/releases/chartmuseum
waitForDeployment chartmuseum chartmuseum

helm delete -n flux helm-operator-chartmuseum
helm delete -n flux helm-operator-secrets
helm delete -n flux helm-operator-ingress

kubectl get hr -A

kubectl get hr -A | grep -vi NAMESPACE | grep -E '(failed)' | awk '{printf "kubectl delete hr -n %s %s\n",$1,$2}' | xargs -I{} -t bash -c '{}'
restartDeployment "flux" "helm-operator-private"
kubectl get hr -A
