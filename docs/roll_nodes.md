# Roll Nodes Procedure

When upgrading Kubernetes, or rolling out some other node configuration
change you may want to replace all of the nodes in the cluster, so you
can use the new configuration as soon as possible.

This repo includes a script `hack/roll_nodes.sh` that can be used to perform
this task in a relatively safe way.

⚠️ ⚠️ ⚠️ WARNING ⚠️ ⚠️ ⚠️
* This guide assumes that the cluster autoscaler is enabled (and working)
* This guide assumes that you have correctly configured kubectl's current context to point at the cluster you are working with, and have configured the aws cli so it can perform operations on the nodes in your cluster.
* This guide recommends running a script that performs potentially destructive actions, make sure you understand what it is doing and why before you run it, anything you break is your own fault!

# Overview

The `hack/roll_nodes.sh` performs the following actions.

* Cordon every node in the cluster, this ensures that we don't reschedule
  workloads to nodes that we will shortly be removing from the cluster.
* For each node in the cluster:
  * Detach the underlying ec2 instance from it's auto scaling group (ASG) - this triggers a new node to be launched and added to the cluster.
  * Wait for the new node to be ready
  * Run kubectl drain so that workloads are migrated to another node
  * Terminate the underlying ec2 node
  * Wait for the number of pods that are not in the Running or Succeeded phase to become 0

# Notes

📝 Since the script uses the `kubectl drain` command it should respect pod disruption
budget. If your application is particularly sensitive to disruption, you
might want to review your configured pod disruption budgets before running the script.
See: https://kubernetes.io/docs/concepts/workloads/pods/disruptions/#pod-disruption-budgets

📝 If you have to pass any flags when you use the aws cli in your environment
update the script on line 13.
