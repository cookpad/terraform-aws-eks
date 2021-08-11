# Terraform EKS Module

![.github/workflows/ci.yml](https://github.com/cookpad/terraform-aws-eks/workflows/.github/workflows/ci.yml/badge.svg)

This repo contains a set of Terraform modules that can be used to provision
an Elastic Kubernetes (EKS) cluster on AWS.

This module provides a way to provision an EKS cluster based on the current
best practices employed by Cookpad's Global SRE team. 

## Using this module

The root module deploys a fully working EKS cluster in its own isolated
network, the IAM resources required for the cluster to operate and a single
pool of worker nodes.

This could be useful if you quickly want to launch a Kubernetes cluster with
minimal extra configuration, for example for testing and development purposes.


```hcl
module "eks" {
  source = "cookpad/eks/aws"
  version = "~> 1.16"

  cluster_name       = "hal-9000"
  cidr_block         = "10.4.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
```
For more advanced uses, we recommend that you construct and configure
your clusters using the submodules.

[see example](https://github.com/cookpad/terraform-aws-eks/blob/main/examples/cluster/main.tf)

This allows for much more flexibility, in order to for example:

* Provision a cluster in an existing VPC.
* Provision multiple clusters in the same VPC.
* Provision several different node types for use by the same cluster.
* To use existing IAM roles.

## Requirements

In order to communicate with kubernetes  correctly this module requires
`kubectl` and the `aws` cli to be installed and on your path.

Note: We considered an approach using the kubernetes terraform provider. But
this required multiple edit - plan - apply cycles to create a cluster.
This module allows a cluster to be created and ready to use in a single PR.

## Multi User Environments

In an environment where multiple IAM users are used to running `terraform run`
and `terraform apply` it is recommended to use the assume role functionality
to assume a common IAM role in the aws provider definition.

```hcl
provider "aws" {
  region              = "us-east-1"
  version             = "3.53.0"
  assume_role {
    role_arn = "arn:aws:iam::<your account id>:role/Terraform"
  }
}
```

[see an example role here](https://github.com/cookpad/terraform-aws-eks/blob/main/examples/iam_permissions/main.tf)

Without this you may encounter difficulties applying kubernetes manifests to
the cluster.

Alternatively you should ensure that all users who need to run terraform
are listed in the `aws_auth_user_map` variable of the cluster module.

## Modules

### `vpc`

This module provisions a VPC with public and private subnets suitable for
launching an EKS cluster into.

### `iam`

This module provisions the IAM roles and policies needed to run an EKS cluster
and nodes.

### `cluster`

This module provisions an EKS cluster, including the EKS Kubernetes control
plane, and several important cluster services (critical addons), and nodes to
run these services.

It will **not** provision any nodes that can be used to run non cluster services.

### `asg_node_group`

This module provisions EC2 autoscaling groups that will make compute resources
available, in order to run Kubernetes pods.
