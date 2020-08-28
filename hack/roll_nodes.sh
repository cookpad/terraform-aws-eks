#!/bin/bash

set -xeuo pipefail

PAUSE=300
CLUSTER_VERSION=$(kubectl version -o json | jq -r .serverVersion.gitVersion)

nodes_to_roll() {
  kubectl get nodes -o json |\
    jq -r ".items | map(select(.status.nodeInfo.kubeletVersion != \"$CLUSTER_VERSION\")) | .[].metadata.name"
}

instance_id() {
  kubectl get nodes -o json |\
    jq -r ".items | map(select(.metadata.name == \"$1\")) | map(.spec.providerID | split(\"/\")[4]) | join(\" \")"
}

for NODE in $(nodes_to_roll)
do
  kubectl cordon $NODE
done

for NODE in $(nodes_to_roll)
do
  kubectl drain --delete-local-data --ignore-daemonsets $NODE
  aws --profile=dev ec2 terminate-instances --instance-ids $(instance_id $NODE)
  sleep $PAUSE
done
