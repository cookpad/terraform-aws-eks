# VPC Module

This module provisions an AWS VPC network that can be used to run EKS clusters.

## Usage

```hcl
provider "aws" {
  region  = "us-east-1"
}

module "vpc" {
  source  = "cookpad/eks/aws//modules/vpc"

  name               = "us-east-1"
  cidr_block         = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
```

This configuration will cause 6 subnets to be launched in the 3 chosen
availability zones.

3 smaller "public" subnets, that can be used for external ingress etc. And
3 larger subnets that will be used for the Pod network, internal ingress and
worker nodes.

In this example the following subnets would be created:

| zone         | public        | private        |
|--------------|---------------|----------------|
| `us-east-1a` | `10.0.0.0/22` | `10.0.32.0/19` |
| `us-east-1b` | `10.0.4.0/22` | `10.0.64.0/19` |
| `us-east-1b` | `10.0.8.0/22` | `10.0.96.0/19` |

This module outputs a [config object](./outputs.tf) that may be used to configure
the cluster module's `vpc_config` variable.

e.g:
```hcl
module "network" {
  source  = "cookpad/eks/aws//modules/vpc"

  name               = "us-west-2"
  cidr_block         = "10.5.0.0/16"
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

module "sal" {
  source  = "cookpad/eks/aws//modules/cluster"

  name               = "sal-9000"
  vpc_config         = module.network.config

  ...
}
```

## Features

As well as configuring the subnets and route table of the provisioned VPC, this
module also provisions internet and NAT gateways, to provide internet access to
nodes running in all subnets.

## Restrictions

In order to run an EKS cluster you must create subnets in at least 3 availability
zones.

Because of the way this module subdivides `cidr_block` it can only accommodate
up to 7 subnet pairs.

The size of each subnet is relative to the CIDR block chosen for the VPC.

## Development

This module is tested by [`test/vpc_test.go`](test/vpc_test.go) which validates
the example configuration in [`examples/vpc`](examples/vpc).

When making additions / changes to the behaviour of this module please ensure
the tests still run successfully, consider testing the behaviour of any new
feature.
