# Karpenter

This module configures the resources required to run the
karpenter node-provisioning tool in an eks cluster.

* Fargate Profile - to run karpenter
* IAM roles for the fargate controller and nodes to be provisioned by karpenter
* SQS queue to provide events (spot interruption etc) to karpenter

It does not install karpenter itself to the cluster - and we recomend
that you use helm as per the [karpenter documentation](https://karpenter.sh/docs/getting-started/getting-started-with-karpenter/#4-install-karpenter)

It is provided as a submodule so the core module is less opinionated.

However we test the core module and the karpenter module
in our test suite to ensure that the different components we use in our
clusters at cookpad intergrate correctly.


## Example

You should pass cluster and oidc config from the cluster to the karpenter module.

You will also need to add the IAM role of nodes created by karpenter to the aws_auth_role_map
so they can connect to the cluster.

```hcl
module "cluster" {
  source     = "cookpad/eks/aws"
  name       = "hal-9000"
  vpc_config = module.vpc.config

  aws_auth_role_map = [
    {
      username = "system:node:{{EC2PrivateDNSName}}"
      rolearn  = module.karpenter.node_role_arn
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    },
  ]
}

module "karpenter" {
  source  = "cookpad/eks/aws//modules/karpenter"

  cluster_config = module.cluster.config
  oidc_config    = module.cluster.oidc_config
}
```
