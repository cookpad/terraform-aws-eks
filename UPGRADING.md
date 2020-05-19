# Upgrade Notes

## 1.14 -> 1.15

### Cluster Security Group

Existing clusters will be using separately managed security groups for cluster
and nodes. To continue to use these (and avoid recreating the cluster) set
`legacy_security_groups = true` on the cluster module.

Update terraform state:

```shell
wget https://raw.githubusercontent.com/cookpad/terraform-aws-eks/master/hack/update_1_15.sh
chmod +x update_1_15.sh
./update_1_15 example-cluster-module
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
