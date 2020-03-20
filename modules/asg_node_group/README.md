# asg_node_group

This module provisions nodes for your cluster by managing AWS auto scaling groups.

## Features

* Will manage spot or on demand instances.
* Provisions an auto scaling group per availability zone, to support applications
  utilizing EBS volumes via PVC.
* Prepares the auto scaling group(s) to be scaled by the cluster auto-scaler.
* Configures a separate EBS volume for use as the docker volume.
* Uses the official AWS EKS optimised Amazon Linux AMI

## Usage

```hcl
module "nodes" {
  source = "cookpad/eks/aws//modules/aws_node_group"

  cluster_config     = module.cluster.config
  max_size           = 60
  instance_family    = "memory_optimized"
  instance_size      = "4xlarge"
}
```

### Instance type selection

There are two ways to choose the instance types launched by the autoscaling
groups:

#### `instance_family` & `instance_size`

The module has 4 preset instance families to choose from (the default is `general_purpose`) :

| family | instance types |
|--------|----------------|
| `memory_optimized`  | `r5`, `r5d`, `r5n`, `r5dn`, `r5a`, `r5ad` |
| `general_purpose`   | `m5`, `m5d`, `m5n`, `m5dn`, `m5a`, `m5ad` |
| `compute_optimized` | `c5`, `c5n`, `c5d` |
| `burstable`         | `t3`, `t3a` |

This is combined with `instance_size` to choose the instance types that the
group will launch.

These groups are useful when utilising spot instances to provide diversity to
avoid the effects of price spikes.

#### `instance_family` & `instance_types`

Alternatively `instance_types` can be used to provide a list of the exact
instance types that will be launched, `instance_family` is used in this
case to provide part of the ASG name.

e.g.
```hcl
module "nodes" {
  source = "cookpad/eks/aws//modules/aws_node_group"

  cluster_config     = module.cluster.config
  max_size           = 16
  instance_family    = "io_optimised"
  instance_types     = ["i3.xlarge", "i3en.xlarge"]
}
```

You may also want to configure the module in this way, when using on-demand
instances, thus diversity is not required!

e.g.
```hcl
module "nodes" {
  source = "cookpad/eks/aws//modules/aws_node_group"

  cluster_config     = module.cluster.config
  instance_family    = "compute_optimized"
  instance_types     = ["c5.large"]
  instance_lifecycle = "on_demand"
}
```

### Labels & taints

You can provide kubernetes labels and/or taints for the nodes, to provide some
control of where your workloads are scheduled.

* https://kubernetes.io/docs/concepts/configuration/assign-pod-node/
* https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/

e.g.
```hcl
module "nodes" {
  source = "cookpad/eks/aws//modules/aws_node_group"

  cluster_config     = module.cluster.config

  labels = {
    "cookpad.com/environment_name" = "production"
    "cookpad.com/department"       = "machine-learning"
  }

  taints = {
    "dedicated" = "gpu:PreferNoSchedule"
  }
}

### Volume size

You can configure the root and docker volume size (they default to 20 GiB).

e.g.

```hcl
module "nodes" {
  source = "cookpad/eks/aws//modules/aws_node_group"

  cluster_config     = module.cluster.config
  root_volume_size   = 10
  docker_volume_size = 50
}

```

### Zone awareness

The module by default provisions 1 ASG per availability zone so the cluster
autoscaler can create instances in particular zone.

If this is not required you can disable this behaviour, and the module will
create a single ASG that will create instances any of your cluster's availability
zones.

e.g.

```hcl
module "nodes" {
  source = "cookpad/eks/aws//modules/aws_node_group"

  cluster_config     = module.cluster.config
  zone_awareness     = false
}

```

### Security groups

The module automatically applies the node security group provided by the cluster
module to each node. This allows access of the nodes to the control plane, and
infra cluster communication between pods running on the cluster.

If you need to add any additional security groups, e.g. for ssh access, configure
`security_groups` with the security group ids.

### SSH key

Set `key_name` to configure a ssh key pair.

### Cloud config

The module will configure the instance user data to use cloud config to add
each node to the cluster, via the eks boots rep script, as well as setting the
instances name tag.

If you need to provide any additional cloud config it will be merged,
see https://cloudinit.readthedocs.io/en/latest/topics/merging.html for more info.
