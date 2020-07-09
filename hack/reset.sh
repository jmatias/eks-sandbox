#!/usr/bin/env bash

SCRIPT_ROOT=$(dirname "${BASH_SOURCE}")/..

if [[ -z "${GITHUB_TOKEN}" ]]; then
  echo nope!
  exit 1
fi


set +e
kubectl get  deployment -n kube-system vpa-updater > /dev/null 2>&1
retVal=$?
if [ $retVal -eq 0 ]; then
  git clone --depth 1 git@github.com:kubernetes/autoscaler.git
  cd autoscaler/vertical-pod-autoscaler/hack || exit
  ./vpa-down.sh
  cd ../../../
  rm -rf autoscaler
fi


helm list -A -a  | grep -vi NAMESPACE  |  awk '{printf "helm delete -n %s %s\n",$2,$1}' | xargs -I{} bash -c '{}'
kubectl get hr -A  | grep -vi NAMESPACE  |  awk '{printf "kubectl delete hr -n %s %s\n",$1,$2}' | xargs -I{}  bash -c '{}'


for dir in ${SCRIPT_ROOT}/base/releases/*
do
    kubectl delete -f $dir
done

kubectl delete -f ${SCRIPT_ROOT}/flux
kubectl delete -f ${SCRIPT_ROOT}/base/namespaces


eksctl delete iamserviceaccount --config-file ${SCRIPT_ROOT}/cluster/cluster.yaml --approve


