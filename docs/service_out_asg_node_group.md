# Service out asg_node_group

When removing a asg_node_group from your cluster, follow the following
guide to avoid disruption to your services.

1. Ensure that you have other node groups that can accept the pods
   currently running on the group you want to service out.
2. Set `cluster_autoscaler = false` on the node group you want to service out, `terraform apply`.
3. Run `hack/drain_nodes.sh group_name` to drain each of the nodes in the group.
4. Remove the `asg_node_group` from your terraform configuration, `terraform apply`.
