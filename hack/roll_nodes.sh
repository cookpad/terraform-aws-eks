#!/bin/bash

# roll_nodes.sh TARGET_VERSION
#
# Replace Kubernetes Nodes, to roll out config changes
#
# This script depends on a correctly configured kubectl, jq and aws cli

set -xeuo pipefail

# If you need some extra aws cli flags in your environment e.g. --profile=foo add
# them here!
AWS_EXTRA_ARGS=""

NODES_TO_ROLL=$(kubectl get nodes -o json |\
  jq -r ".items | .[].metadata.name"
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
  while [ $(kubectl get pods --all-namespaces -o json | jq '.items | map(select(.status.phase=="Running" | not)) | map(select(.status.phase=="Succeeded" | not)) | length') -gt 0 ]
  do
    sleep 10
  done
}

detach() {
  rolled=$(nodes_rolled)
  aws $AWS_EXTRA_ARGS autoscaling detach-instances \
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
  aws $AWS_EXTRA_ARGS ec2 terminate-instances --instance-ids $instance
  wait_for_pods
done
