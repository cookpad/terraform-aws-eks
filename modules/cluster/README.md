# cluster module

This module provisions an EKS cluster, including the EKS Kubernetes control
plane, and several important cluster services (critial addons), and nodes to
run these services.

It will **not** provision any nodes that can be used to run non cluster services.
You will need to provision nodes for your workloads separately using the `asg_node_group` module.

## Usage

```hcl
module "cluster" {
  source = "cookpad/eks/aws//modules/cluster"

  name = "sal-9000"

  vpc_config = module.vpc.config
  iam_config = module.iam.config
}
```

[see example](../../examples/cluster/main.tf)

## Features

* Provision a Kubernetes Control Plane by creating and configuring an EKS cluster.
  * Configure cloudwatch logging for the control plane
  * Configures [envelope encryption](https://aws.amazon.com/about-aws/whats-new/2020/03/amazon-eks-adds-envelope-encryption-for-secrets-with-aws-kms/) for Kubernetes secrets with KMS
* Provisions a node group dedicated to running critical cluster level services:
  * [cluster-autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)
  * [metrics-server](https://github.com/kubernetes-sigs/metrics-server)
  * [prometheus-node-exporter](https://github.com/prometheus/node_exporter)
  * [aws-node-termination-handler](https://github.com/aws/aws-node-termination-handler)
* Configures EKS [cluster authentication](https://docs.aws.amazon.com/eks/latest/userguide/managing-auth.html)
* Provisions security groups for node to cluster and infra node communication.
* Supports [IAM Roles for service accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

## aws-auth mappings

In order to map IAM Roles or Users to Kubernetes groups you can provide config
in `aws_auth_role_map` and `aws_auth_user_map`.

The module automatically adds the node role to the `system:bootstrappers` and
`system:nodes` groups (that are required for nodes to join the cluster).

example:

```hcl
module "cluster" {
  source = "cookpad/eks/aws//modules/cluster"
  ...
  aws_auth_role_map = [
    {
      username = "PowerUser"
      role_arn = "arn:aws:iam::123456789000:role/PowerUser"
      groups   = ["system:masters"]
    },
    {
      username = "ReadOnlyUser"
      role_arn = "arn:aws:iam::123456789000:role/ReadonlyUser"
      groups   = ["myreadonlygroup"]
    }
  ]

  aws_auth_user_map = [
    {
      username = "cookpadder"
      role_arn = "arn:aws:iam::123456789000:user/admin/cookpadder"
      groups   = ["system:masters"]
    }
  ]
```

## Secret encryption

This feature is enabled by default, but may be disabled by setting
`envelope_encryption_enabled = false`

When enabled secrets are automatically encrypted with a Kubernetes-generated
data encryption key, which is then encrypted using a KMS master key.

By default a new KMS customer master key is generated per cluster, but you may
specify the arn of an existing key by setting `kms_cmk_arn`

## Cluster critical add-ons


| addon | variable | default | iam role variable |
|-------|----------|---------|-------------------|
| [Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler) | `cluster_autoscaler` | ✅ enabled | `cluster_autoscaler_iam_role_arn` |
| [AWS Node Termination Handler](https://github.com/aws/aws-node-termination-handler) | `aws_node_termination_handler` | ✅ enabled ||
| [NVIDIA device plugin for Kubernetes](https://github.com/NVIDIA/k8s-device-plugin) | `nvidia_device_plugin` | ✅ enabled (but only schedules to gpu nodes) ||
| [Prometheus Node Exporter](https://github.com/prometheus/node_exporter) | `prometheus_node_exporter` | ❌ disabled ||
| [Kubernetes Metrics Server](https://github.com/kubernetes-sigs/metrics-server) | `metrics_server` | ❌ disabled ||
| [Amazon Elastic Block Store (EBS) CSI driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver/) | `aws_ebs_csi_driver` | ❌ disabled | `aws_ebs_csi_driver_iam_role_arn` |
| [AWS Load Balancer Controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller) | `aws_load_balancer_controller` | ❌ disabled | `aws_load_balancer_controller_iam_role_arn` |

Note that setting these variables to false will not remove provisioned add-ons from an existing cluster.

Some addons require an IAM role in order to provide the appropriate permissions to read or modify AWS resources.
If enabled these addons will provision an IAM role for this purpose.

If you wish to avoid this, for example because you manage IAM roles with some other external process, you may specify an IAM role ARN for the addon to assume,
and the module will skip provisioning an IAM role.
