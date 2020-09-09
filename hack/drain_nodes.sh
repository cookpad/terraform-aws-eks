#!/bin/bash

# drain_nodes.sh ASG_NAME
#
# Drain Kubernetes Nodes, before removing asg_node_group
#
# This script depends on a correctly configured kubectl and jq

set -euo pipefail

NODES_TO_DRAIN=$(kubectl get nodes -l "node-group.k8s.cookpad.com/name=$1" -o json |\
  jq -r ".items | .[].metadata.name"
)

wait_for_pods() {
  printf "waiting for pods to be rescheduled "
  while [ $(kubectl get pods --all-namespaces -o json | jq '.items | map(select(.status.phase=="Running" | not)) | map(select(.status.phase=="Succeeded" | not)) | length') -gt 0 ]
  do
    printf "."
    sleep 10
  done
  echo
}

for NODE in $NODES_TO_DRAIN
do
  kubectl cordon $NODE
done

for NODE in $NODES_TO_DRAIN
do
  kubectl drain --delete-local-data --ignore-daemonsets $NODE
  wait_for_pods
done
