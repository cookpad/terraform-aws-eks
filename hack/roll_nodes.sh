#!/bin/bash

PAUSE="5m"
CLUSTER_VERSION=$(kubectl version -o json | jq -r .serverVersion.gitVersion)

nodes_to_roll() {
  kubectl get nodes -o json |\
    jq -r '.items | map(select(.nodeInfo.kubeletVersion != "$CLUSTER_VERSION")) | .[].metadata.name'
}

nodes_to_terminate() {
  kubectl get nodes -o json |\
    jq -r '.items |\
      map(select(.spec.taints | any(contains({key: "node.kubernetes.io/unschedulable", "effect": "NoSchedule"})))) |\
      map(select(.nodeInfo.kubeletVersion != "$CLUSTER_VERSION")) |\
      map(.spec.providerID | split("/")[4]) | join(" ")'
}

for NODE in $(nodes_to_roll)
do
  kubectl cordon $NODE
done

for NODE in $(nodes_to_roll)
do
  kubectl drain --delete-local-data --ignore-daemonsets $NODE
  aws ec2 terminate-instances --instance-ids $(nodes_to_terminate)
  sleep $PAUSE
done
