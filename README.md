# Terraform EKS Module

This repo contains a set of Terraform modules that can be used to provision
a Elastic Kubernetes (EKS) cluster on AWS.

This module provides a way to provision an EKS cluster based on the current
best practices employed by Cookpad's Global SRE team. 

## Using this module

The root module deploys a fully working EKS cluster in it's own isolated
network, the IAM resources required for the cluster to operate and a single
pool of worker nodes.

This could be useful if you quickly want to launch a Kubernetes cluster with
minimal extra configuration, for example for testing and development purposes.


```hcl
provider "aws" {
  region  = "us-east-1"
  version = "~> 2.52"
}


module "eks" {
  source = "cookpad/eks/aws"

  cluster_name       = "hal-9000"
  cidr_block         = "10.4.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
```
[see example](./examples/eks)

For more advanced uses, we recommend that you construct and configure
your clusters using the modules contained within the [`modules`](./modules) folder.

This allows for much more flexibility, in order to for example:

* Provision a cluster in an existing VPC.
* Provision multiple clusters in the same VPC.
* Provision several different node types for use by the same cluster.
* To use existing IAM roles.

## Modules

### [vpc](./modules/vpc)

This module provisions a VPC with public and private subnets suitable for
launching an EKS cluster into.

### [iam](./modules/iam)

This module provisions the IAM roles and policies needed to run an EKS cluster
and nodes.

### [cluster](./modules/cluster)

This module provisions an EKS cluster, including the EKS Kubernetes control
plane, and several important cluster services (critial addons), and nodes to
run these services.

It will **not** provision any nodes that can be used to run non cluster services.

### [asg_node_group](./modules/asg_node_group)

This module provisions EC2 autoscaling groups that will make compute resources
available, in order to run Kuberntes pods.
