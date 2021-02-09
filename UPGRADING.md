# Upgrade Notes

## All Upgrades

* Check the notes for the Kubernetes version you are upgrading to at https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
* After upgrading the terraform module, remember to follow the [roll nodes](docs/roll_nodes.md) procedure to roll out upgraded nodes to your cluster.

## 1.17 -> 1.18

[#170](https://github.com/cookpad/terraform-aws-eks/pull/170) renames the cluster-module and root module outputs
`odic_config` -> `oidc_config`. If you are using this output you will need to update it.
## 1.15 -> 1.16

Some deprecated API versions are removed by this version of Kubernetes.

Make sure you follow the instructions at https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html#1-16-prequisites
before upgrading your cluster.

---

Metrics Server and Prometheus Node Exporter will not be managed by this module
by default.

To retain the previous behaviour set:

```
  metrics_server              = true
  prometheus_node_exporter    = true
```

📝 existing resources won't be removed by this update, so you will need to remove
them manually if they are no longer required. This change means that they will not
be created in a new cluster, or receive updates from this module!

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
