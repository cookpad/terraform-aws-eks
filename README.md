# Terraform EKS Module

![.github/workflows/ci.yml](https://github.com/cookpad/terraform-aws-eks/workflows/.github/workflows/ci.yml/badge.svg)

This repo contains a set of Terraform modules that can be used to provision
an Elastic Kubernetes (EKS) cluster on AWS.

This module provides a way to provision an EKS cluster based on the current
best practices employed by Cookpad's Global SRE team. 

## Using this module

We recommend setting up your cluster(s) using the submodules.

This will allow you to flexibly manage and grow the configuration of your
cluster(s) over time, you can also pick and choose the parts of the configuration
you want to manage with these modules.

This setup allows you to:

* Easily add (and remove) additional node groups to your cluster.
* Easily add additional clusters to your VPC.
* Provision a cluster to an existing VPC (assuming it has the correct subnets setup)

```hcl
module "vpc" {
  source  = "cookpad/eks/aws//modules/vpc"
  version = "~> 1.19"

  name               = "us-east-1"
  cidr_block         = "10.4.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

module "iam" {
  source  = "cookpad/eks/aws//modules/iam"
  version = "~> 1.19"
}


module "cluster" {
  source  = "cookpad/eks/aws//modules/cluster"
  version = "~> 1.19"

  name       = "hal-9000"

  vpc_config = module.vpc.config
  iam_config = module.iam.config
}

module "node_group" {
  source  = "cookpad/eks/aws//modules/asg_node_group"
  version = "~> 1.19"

  cluster_config = module.cluster.config

  max_size           = 60
  instance_family    = "burstable"
  instance_size      = "medium"
}
```

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
