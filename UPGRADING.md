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
