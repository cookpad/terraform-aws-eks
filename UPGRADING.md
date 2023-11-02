# Upgrade Notes

## All Upgrades

* Check the notes for the Kubernetes version you are upgrading to at https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
* After upgrading the terraform module, remember to follow the [roll nodes](docs/roll_nodes.md) procedure to roll out upgraded nodes to your cluster.
* If providing custom `configuration_values` for any EKS addons, check for compatibility with the upgraded EKS addon version, using `aws eks describe-addon-configuration`. You can find the EKS addon versions in [addons.tf](modules/cluster/addons.tf)

## 1.24 -> 1.25
 * Check the [API deprecation guide](https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-25)
   * If you are using aws-load-balancer-controller, check you are on version 2.4.7+
   * Check that you are not using Pod Security Policies (PSPs)
     * Run `kubectl get psp --all-namespaces` to check - `eks.privileged` is OK as it will be automaticly migrated during the upgrade!
 * Check [The AWS blogpost about this version](https://aws.amazon.com/blogs/containers/amazon-eks-now-supports-kubernetes-version-1-25/)
 * IAM module was removed
  * By default the module now makes IAM roles for each cluster rather than using shared roles
  * ⚠️  if you are upgrading an existing cluster be sure to set `cluster_role_arn` to it's previous default value, i.e. `arn:aws:iam::<account number>:role/eksServiceRole` This value cannot be changed, so terraform will attempt to delete and recreate the cluster. ⚠️
 * Cluster module is no longer a submodule
   * change `source` from `cookpad/eks/aws//modules/cluster` to `cookpad/eks/aws`
 * `node_group` submodule was removed
   * We recommend to use karpenter to provision nodes for eks clusters
   * A new submodule [`cookpad/eks/aws//modules/karpenter`](https://github.com/cookpad/terraform-aws-eks/tree/release-1-25/modules/karpenter) was added that provisions the resources required to use karpenter.
 * Module now uses terraform kubernetes provider
   * Provider config should be added to your project - [check the example in the README](https://github.com/cookpad/terraform-aws-eks/tree/release-1-25#using-this-module)
   * Take special care to correctly configure the provider if you are managing more than one EKS cluster in the same terraform project.
   * If upgrading an existing cluster import existing `aws-auth` configmap from your cluster - e.g. `terraform import module.cluster.kubernetes_config_map.aws_auth kube-system/aws-auth`
 * 1.25+ uses fargate to run cluster critical pods from `kube-system`, `flux-system` and optionaly `fargate`
   * It is recomended to first upgrade the module to 1.24.3+ and add the karpenter sub-module before upgrading to 1.25 - so that the fargate profiles are created
     before the ASG that managed these "critical" addons is removed.
 * We removed the `hack/roll_nodes.sh` script from version 1.25
   * To replace fargate nodes with new version it is recomended to:
     * kubectl get deployment in each of the enabled namespaces e.g. kube-system, flux-system, karpenter
     * kubectl rollout restart deployment/<name> for each deployment
   * To have karpenter rollout the new version to the nodes that it manages:
    * Consider using the [drift](https://karpenter.sh/preview/concepts/disruption/#drift) feature
      * `kubectl edit configmap -n karpenter karpenter-global-settings`
      * set `featureGates.driftEnabled` to true
      * `kubectl rollout restart deploy karpenter -n karpenter` to restart karpenter with the drift feature enabled
      * 📝 this feature is currently in alpha, so consider if you want to leave it perminantly enabled

## 1.23 -> 1.24
 * Dockershim support is removed. Make sure none of your workload requires Docker functions specifically. Read more [here](https://docs.aws.amazon.com/eks/latest/userguide/dockershim-deprecation.html).
 * IPv6 is enabled for pods by default. Check your multi-container pods, make sure they can bind to all loopback interfaces IP address (IPv6 is the default for communication).

## 1.22 -> 1.23
 * [324](https://github.com/cookpad/terraform-aws-eks/pull/324) EBS CSI driver is now non-optional. Check your cluster module's `aws_ebs_csi_driver` variable. Refer to [this AWS FAQ](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi-migration-faq.html).

## 1.21 -> 1.22
 * Removed yaml k8s addons: nvidia, aws-node-termination-handler, metrics-server, pod_nanny (PR) only remains cluster-autoscaler, The idea is that terraform doesn't manage anymore k8s components in future releases, just the AWS Addons. So Flux or any GitOps system should manage k8s components.

## 1.20 -> 1.21
 * [261](https://github.com/cookpad/terraform-aws-eks/issues/267/) 💥 Breaking Change. Modules now require terraform version >=1.0.

## 1.19 -> 1.20
 * [247](https://github.com/cookpad/terraform-aws-eks/pull/247) 💥 Breaking Change. The `k8s_version` variable has been removed. Use the correct version of the module for the k8s version you want to use.
 * [156](https://github.com/cookpad/terraform-aws-eks/issues/156) 💥 Breaking Change. The root module has been removed. Please refactor using the README as a guide.
 * [276](https://github.com/cookpad/terraform-aws-eks/pull/276) 💥 Breaking Change. The `dns_cluster_ip` variable has been removed from the `asg_node_group` module.
 * [240](https://github.com/cookpad/terraform-aws-eks/pull/240/) 💥 Breaking Change. Public access to EKS Clusters is disabled by default.
 * [261](https://github.com/cookpad/terraform-aws-eks/pull/261/) 💥 Breaking Change. Node module requires terraform version >=0.14, upgrade your terraform version if using <= 0.13.

## 1.18 -> 1.19

 * [#204](https://github.com/cookpad/terraform-aws-eks/pull/204) EKS no longer adds `kubernetes.io/cluster/<cluster-name>` to subnets. They will not be removed on upgrading to 1.19, but we recommend to codify the tags yourself for completeness if you are not using the vpc module and you want to keep using auto-discovery with eks-load-balancer-controller.
 * [#203](https://github.com/cookpad/terraform-aws-eks/pull/203) removes `failure-domain.beta.kubernetes.io/zone` label which is deprecated in favour of `topology.kubernetes.io/zone`. Use the new label in any affinity specs.
 * [#195](https://github.com/cookpad/terraform-aws-eks/pull/295) / [#225](https://github.com/cookpad/terraform-aws-eks/pull/225) removes the `aws-alb-ingress-controller` addon. The upgrade will not delete the addon from the cluster but takes it out of control of the module, so users should manage the package themselves through another mechanism.

## 1.18.3+

This release updated ebs-csi-driver, 
The upgrade renamed the ebs-csi-controller-pod-disruption-budget resource.

Due to the way that we apply manifests this will result in a duplicated pod disruption
budget, that can cause issues when trying to drain nodes.

Ensure you run `kubectl -n kube-system delete pdb ebs-csi-controller-pod-disruption-budget`
after upgrading to this version of the module to avoid this issue.


## 1.17 -> 1.18

 * [#170](https://github.com/cookpad/terraform-aws-eks/pull/170) renames the cluster-module and root module outputs
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
