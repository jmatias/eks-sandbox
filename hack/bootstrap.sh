#!/usr/bin/env bash


if [[ -z "${GITHUB_TOKEN}" ]]; then
  echo nope!
  exit 1
fi

SCRIPT_ROOT=$(dirname "${BASH_SOURCE}")/..

clusterName=$(yq .metadata.name - < $SCRIPT_ROOT/cluster/cluster.yaml)
clusterName=$(echo "$clusterName" | sed -e 's/^"//' -e 's/"$//')

eksctl get cluster "$clusterName"
retVal=$?

set -e

if [ $retVal -ne 0 ]; then
    eksctl create cluster --config-file ${SCRIPT_ROOT}/cluster/cluster.yaml
fi

set +e
git clone --depth 1 git@github.com:kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler/hack
./vpa-up.sh
cd ../../../
rm -rf autoscaler


set -e
kubectl patch deployments.apps -n flux flux --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/10", "value": "--sync-interval=3m" }]'
kubectl patch deployments.apps -n flux flux --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/10", "value": "--git-poll-interval=3m" }]'


helm upgrade -i helm-operator-public fluxcd/helm-operator  --set helm.versions=v3 --namespace flux --set workers=10

kubectl rollout restart deployment -n flux flux
kubectl rollout status deployment -n flux flux

set +e
until helm status -n external-secrets external-secrets
do
    echo Waiting for external-secrets...
    sleep 5
done

set -e
kubectl rollout status deployment -n external-secrets external-secrets-kubernetes-external-secrets

set +e
until helm status -n chartmuseum chartmuseum
do
    echo Waiting for chartmuseum...
    sleep 5
done

set -e
kubectl rollout status deployment -n chartmuseum chartmuseum-chartmuseum


helm delete -n flux helm-operator-public

kubectl rollout restart deployment -n flux flux
kubectl rollout status deployment -n flux flux

kubectl rollout restart deployment -n flux helm-operator-private
kubectl rollout status deployment -n flux helm-operator-private

kubectl get hr -A  | grep -vi NAMESPACE  |  grep -E '(failed)' |  awk '{printf "kubectl delete hr -n %s %s\n",$1,$2}' | xargs -I{} -t bash -c '{}'

