# Terraform EKS Module

![.github/workflows/ci.yml](https://github.com/cookpad/terraform-aws-eks/workflows/.github/workflows/ci.yml/badge.svg)

This repo contains a set of Terraform modules that can be used to provision
an Elastic Kubernetes (EKS) cluster on AWS.

This module provides a way to provision an EKS cluster based on the current
best practices employed at Cookpad.

## Using this module

To provision an EKS cluster you need (as a minimum) to specify
a name, and the details of the VPC network you will create it in.

```hcl
module "cluster" {
  source  = "cookpad/eks/aws"
  version = "~> 1.25"

  name       = "hal-9000"

  vpc_config = {
    vpc_id = "vpc-345abc"

    public_subnet_ids = {
      use-east-1a = subnet-000af1234
      use-east-1b = subnet-123ae3456
      use-east-1c = subnet-456ab6789
    }

    private_subnet_ids = {
      use-east-1a = subnet-123af1234
      use-east-1b = subnet-456bc3456
      use-east-1c = subnet-789fe6789
    }
  }
}

provider "kubernetes" {
  host                   = module.cluster.config.endpoint
  cluster_ca_certificate = base64decode(module.cluster.config.ca_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.cluster.config.name]
  }
}
```

There are many options that can be set to configure your cluster.
Check the [input documentation](https://registry.terraform.io/modules/cookpad/eks/aws/latest?tab=inputs) for more information.


## Networking

If you only have simple networking requirements you can use the
submodule `cookpad/eks/aws/modules/vpc` to create a VPC, it's output
variable `config` can be used to configure the `vpc_config` variable.

Check the [VPC module documentation](https://registry.terraform.io/modules/cookpad/eks/aws/latest/submodules/vpc) for more extensive information.

## Karpenter

We use karpenter to provision the nodes that run the workloads in
our clusters. You can use the submodule `cookpad/eks/aws/modules/vpc`
to provision the resources required to use karpenter, and a fargate
profile to run the karpenter pods.

Check the [Karpenter module documentation](https://registry.terraform.io/modules/cookpad/eks/aws/latest/submodules/karpenter) for more information.

## Requirements

In order for this module to communicate with kubernetes correctly this module
requires the `aws` cli to be installed and on your path.

You will need to initialise the kuberntes provider as shown in the
example.

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


Alternatively you should ensure that all users who need to run terraform
are listed in the `aws_auth_user_map` variable of the cluster module.
