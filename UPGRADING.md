# Upgrade Notes

## All Upgrades

* Check the notes for the Kubernetes version you are upgrading to at https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
* After upgrading the terraform module, remember to follow the [roll nodes](docs/roll_nodes.md) procedure to roll out upgraded nodes to your cluster.

## 1.19 -> 1.20
[247](https://github.com/cookpad/terraform-aws-eks/pull/247) 💥 Breaking Change. The `k8s_version` variable has been removed. Use the correct version of the module for the k8s version you want to use.
[156](https://github.com/cookpad/terraform-aws-eks/issues/156) 💥 Breaking Change. The root module has been removed. Please refactor using the README as a guide.

## 1.18 -> 1.19

[#204](https://github.com/cookpad/terraform-aws-eks/pull/204) EKS no longer adds `kubernetes.io/cluster/<cluster-name>` to subnets. They will not be removed on upgrading to 1.19, but we recommend to codify the tags yourself for completeness if you are not using the vpc module and you want to keep using auto-discovery with eks-load-balancer-controller.
[#203](https://github.com/cookpad/terraform-aws-eks/pull/203) removes `failure-domain.beta.kubernetes.io/zone` label which is deprecated in favour of `topology.kubernetes.io/zone`. Use the new label in any affinity specs.
[#195](https://github.com/cookpad/terraform-aws-eks/pull/295) / [#225](https://github.com/cookpad/terraform-aws-eks/pull/225) removes the `aws-alb-ingress-controller` addon. The upgrade will not delete the addon from the cluster but takes it out of control of the module, so users should manage the package themselves through another mechanism.

## 1.18.3+

This release updated ebs-csi-driver, 
The upgrade renamed the ebs-csi-controller-pod-disruption-budget resource.

Due to the way that we apply manifests this will result in a duplicated pod disruption
budget, that can cause issues when trying to drain nodes.

Ensure you run `kubectl -n kube-system delete pdb ebs-csi-controller-pod-disruption-budget`
after upgrading to this version of the module to avoid this issue.


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
wget https://raw.githubusercontent.com/cookpad/terraform-aws-eks/main/hack/update_1_15.sh
chmod +x update_1_15.sh
./update_1_15.sh example-cluster-module
```
