# Upgrade Notes

## Node Rollout Procedure

When upgrading the version of `asg_node_group` module, nodes that are currently
running will continue to run until there normal lifecycle ends, e.g. a spot termination
or autoscaling event.

It is best practice to roll out the new node configuration as soon as possible.
You can do this by following the following procedure:

📝 This guide assumes that the cluster autoscaler is enabled (and working)
📝 This guide assumes that you have correctly configured kubectl's current context to point at the cluster you are working with.
📝 Before following this guide made sure you upgraded the version of the cluster and asg_node_group modules in your cluster!


1. Check that the `max_size` of each asg is large enough to support adding some
   additional nodes!

1. (Optional) Overprovision the cluster

   `kubectl apply -f hack/overprovisioning.yaml`

   This manifest deploys some pod(s) that request (but don't use)
   resources. Because they use a special low priortyclass all other workloads
   will take priority. This causes the cluster autoscaler to provision extra
   nodes.

   You might need to alter the resource requests to match the size of typical
   workloads in your cluster.

   This is useful if you want to minimise the time that it takes for kubernetes
   to reschedule your workloads after draining a node, if your applications
   run on many nodes, and are resilient to single nodes going down, you
   might not need to worry about this step!

1. Roll nodes:

   `hack/roll_nodes.sh`

   This script performs the follow actions:

   * Cordons each node where the kubelet version does not match the cluster k8s version
   * Then drains each node and terminates it's ec2 instance, before pausing for 5 minutes

   📝 Since the script uses the `kubectl drain` command it should respect pod disruption
   budget. If your application is particularly sensitive to disruption, you
   might want to increase the time between each node drain, by altering the value of `PAUSE`

   📝 If you have to pass any flags when you use the aws cli in your environment
   update the script on line 27

3. `kubectl delete deployment/overprovisioning`

## 1.14 -> 1.15

### Cluster Security Group

Existing clusters will be using separately managed security groups for cluster
and nodes. To continue to use these (and avoid recreating the cluster) set
`legacy_security_groups = true` on the cluster module.

Update terraform state:

```shell
wget https://raw.githubusercontent.com/cookpad/terraform-aws-eks/master/hack/update_1_15.sh
chmod +x update_1_15.sh
./update_1_15.sh example-cluster-module
```

## 1.15 -> 1.16

Metrics Server and Prometheus Node Exporter will not be managed by this module
by default.

To retain the previous behaviour set:

```
  metrics_server              = true
  prometheus_node_exporter    = true
```

📝 existing resources won't be removed by this update, you will need to remove
them manually if they are no longer required. This change means that they will not
be created in a new cluster, or receive updates from this module!
