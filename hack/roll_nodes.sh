#!/bin/bash

# roll_nodes.sh TARGET_VERSION
#
# Replace Kubernetes Nodes, to roll out config changes
#
# TARGET_VERSION - The kubelet version you want to be running. Defaults to the EKS server version.
# This is normally what you want when doing an EKS upgrade, if you are rolling out new node config
# for some other reason, you might want to set this to `all` so we don't match any nodes, and just
# replace them all!
#
# This script depends on a correctly configured kubectl, jq and aws cli

set -xeuo pipefail

TARGET_VERSION="${2:-$(kubectl version -o json | jq -r .serverVersion.gitVersion)}"

NODES_TO_ROLL=$(kubectl get nodes -o json |\
  jq -r ".items | map(select(.status.nodeInfo.kubeletVersion != \"$TARGET_VERSION\")) | .[].metadata.name"
)

instance_id() {
  kubectl get nodes/$1 -o json |\
    jq -r '.spec.providerID | split("/")[4]'
}

autoscaling_group_name() {
  aws ec2 describe-tags --output json \
    --filters \
      Name=resource-id,Values=$1 \
      Name=key,Values=aws:autoscaling:groupName |\
    jq -r '.Tags[].Value'
}

nodes_rolled() {
  kubectl get nodes --field-selector spec.unschedulable!=true -o json |\
    jq -r '.items | map(select(any(.status.conditions[]; contains({"reason": "KubeletReady","status": "True"})))) | length'
}

wait_for_pods() {
  while [ $(kubectl get pods --all-namespaces --field-selector status.phase!=Running -o json | jq -r '.items | length') -gt 0 ]
  do
    sleep 10
  done
}

detach() {
  rolled=$(nodes_rolled)
  aws autoscaling detach-instances \
    --instance-ids $1 \
    --auto-scaling-group-name $(autoscaling_group_name $1) \
    --no-should-decrement-desired-capacity
  while [ $(nodes_rolled) -le $rolled ]
  do
    sleep 10
  done
}

for NODE in $NODES_TO_ROLL
do
  kubectl cordon $NODE
done

for NODE in $NODES_TO_ROLL
do
  instance=$(instance_id $NODE)
  detach $instance
  kubectl drain --delete-local-data --ignore-daemonsets $NODE
  aws ec2 terminate-instances --instance-ids $instance
  wait_for_pods
done
