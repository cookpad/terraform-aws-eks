# IAM module

This module configures the IAM roles needed to run an EKS cluster.

## Features

* Configures a service role to be assumed by an EKS cluster.
* Configures a role and instance profile for use by EC2 worker nodes.

This module outputs a config object that may be used to configure the cluster module's `iam_config` variable.

## Usage

```hcl
module "iam" {
  source  = "cookpad/eks/aws//modules/iam"
}

module "cluster" {
  source     = "cookpad/eks/aws//modules/cluster"
  name       = "sal-9000"
  iam_config = module.iam.config
  ...
}
```
