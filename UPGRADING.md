# Upgrade Notes

## 1.14 -> 1.15

### Cluster Security Group

Existing clusters will be using separately managed security groups for cluster
and nodes. To continue to use these (and avoid recreating the cluster) set
`legacy_security_groups = true` on the cluster module.

Update terraform state:

```shell
export MODULE_NAME=example-cluster
terraform state mv module.$MODULE_NAME.aws_security_group.control_plane module.$MODULE_NAME.aws_security_group.control_plane[0]
terraform state mv module.$MODULE_NAME.aws_security_group.node module.$MODULE_NAME.aws_security_group.node[0]
terraform state mv module.$MODULE_NAME.aws_security_group_rule.node_ingress_self module.$MODULE_NAME.aws_security_group_rule.node_ingress_self[0]
terraform state mv module.$MODULE_NAME.aws_security_group_rule.node_ingress_cluster module.$MODULE_NAME.aws_security_group_rule.node_ingress_cluster[0]
terraform state mv module.$MODULE_NAME.aws_security_group_rule.cluster_ingress_node_https module.$MODULE_NAME.aws_security_group_rule.cluster_ingress_node_https[0]
```
