locals {
  k8s_version = "1.22"
  preset_instance_families = {
    memory_optimized  = ["r5", "r5d", "r5n", "r5dn", "r5a", "r5ad"]
    general_purpose   = ["m5", "m5d", "m5n", "m5dn", "m5a", "m5ad"]
    compute_optimized = ["c5", "c5n", "c5d"]
    burstable         = ["t3", "t3a"]
  }

  instance_types       = length(var.instance_types) > 0 ? var.instance_types : [for instance_family in local.preset_instance_families[var.instance_family] : "${instance_family}.${var.instance_size}"]
  instance_overrides   = var.instance_lifecycle == "spot" ? local.instance_types : [local.instance_types[0]]
  name_prefix          = replace(join("-", compact(["eks-node", var.cluster_config.name, var.name, var.instance_family, var.instance_size, var.instance_lifecycle])), "_", "-")
  asg_subnets          = var.zone_awareness ? { for az, subnet in var.cluster_config.private_subnet_ids : az => [subnet] } : { "multi-zone" = values(var.cluster_config.private_subnet_ids) }
  max_size             = floor(var.max_size / length(local.asg_subnets))
  min_size             = ceil(var.min_size / length(local.asg_subnets))
  root_device_mappings = var.bottlerocket ? tolist(data.aws_ami.bottlerocket_image.block_device_mappings)[0] : tolist(data.aws_ami.image.block_device_mappings)[0]
  autoscaler_tags      = var.cluster_autoscaler ? { "k8s.io/cluster-autoscaler/enabled" = "true", "k8s.io/cluster-autoscaler/${var.cluster_config.name}" = "owned" } : {}
  bottlerocket_tags    = var.bottlerocket ? { "Name" = "eks-node-${var.cluster_config.name}" } : {}
  tags                 = merge(var.cluster_config.tags, var.tags, { "kubernetes.io/cluster/${var.cluster_config.name}" = "owned" }, local.autoscaler_tags, local.bottlerocket_tags)
  node_group_label     = var.name != "" ? var.name : local.name_prefix
  cloud_config = templatefile(
    "${path.module}/cloud_config.tpl",
    {
      cluster_name = var.cluster_config.name
      labels       = join(",", [for label, value in local.labels : "${label}=${value}"])
      taints       = join(",", [for taint, value_effect in var.taints : "${taint}=${value_effect}"])
    }
  )
  bottlerocket_config = templatefile(
    "${path.module}/bottlerocket_config.toml.tpl",
    {
      cluster_name                 = var.cluster_config.name
      cluster_endpoint             = var.cluster_config.endpoint
      cluster_ca_data              = var.cluster_config.ca_data
      node_labels                  = join("\n", [for label, value in local.labels : "\"${label}\" = \"${value}\""])
      node_taints                  = join("\n", [for taint, value in var.taints : "\"${taint}\" = \"${value}\""])
      admin_container_enabled      = var.bottlerocket_admin_container_enabled
      admin_container_superpowered = var.bottlerocket_admin_container_superpowered
      admin_container_source       = var.bottlerocket_admin_container_source
    }
  )

  labels = merge(
    { "node-group.k8s.cookpad.com/name" = local.node_group_label },
    var.gpu ? { "nvidia.com/gpu" = "true" } : {},
    var.bottlerocket ? { "bottlerocket" = "true" } : {},
    var.labels,
  )
}

data "assert_test" "node_group_label" {
  test  = length(local.node_group_label) < 64
  throw = "node-group.k8s.cookpad.com/name label must be 63 characters or less. Set `name` or shorten `cluster-config.name`."
}

data "aws_ssm_parameter" "image_id" {
  name = "/aws/service/eks/optimized-ami/${local.k8s_version}/amazon-linux-2${var.gpu ? "-gpu" : ""}/recommended/image_id"
}

data "aws_ami" "image" {
  owners = ["amazon"]
  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.image_id.value]
  }
}

data "aws_ssm_parameter" "bottlerocket_image_id" {
  name = "/aws/service/bottlerocket/aws-k8s-${local.k8s_version}${var.gpu ? "-nvidia" : ""}/x86_64/latest/image_id"
}

data "aws_ami" "bottlerocket_image" {
  owners = ["amazon"]
  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.bottlerocket_image_id.value]
  }
}

data "aws_region" "current" {}

resource "aws_launch_template" "config" {
  image_id               = var.bottlerocket ? data.aws_ami.bottlerocket_image.id : data.aws_ami.image.id
  name                   = local.name_prefix
  vpc_security_group_ids = concat([var.cluster_config.node_security_group], var.security_groups)
  user_data              = var.bottlerocket ? base64gzip(local.bottlerocket_config) : base64gzip(local.cloud_config)

  instance_type = local.instance_types.0

  iam_instance_profile {
    name = var.cluster_config.node_instance_profile
  }

  block_device_mappings {
    device_name = local.root_device_mappings.device_name

    ebs {
      volume_size = var.root_volume_size
      volume_type = local.root_device_mappings.ebs.volume_type
      snapshot_id = local.root_device_mappings.ebs.snapshot_id
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = var.imdsv2_required ? "required" : "optional"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.tags
  }

  tags = local.tags

  key_name = var.key_name
}

resource "aws_autoscaling_group" "nodes" {
  for_each = local.asg_subnets

  name                      = "${local.name_prefix}-${each.key}"
  min_size                  = local.min_size
  max_size                  = local.max_size
  vpc_zone_identifier       = each.value
  termination_policies      = var.termination_policies
  enabled_metrics           = var.enabled_metrics
  wait_for_capacity_timeout = "10m"

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.config.id
        version            = "$Latest"
      }

      dynamic "override" {
        for_each = local.instance_types
        content {
          instance_type = override.value
        }
      }
    }

    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = (var.instance_lifecycle == "on_demand" ? 100 : 0)
      spot_allocation_strategy                 = var.spot_allocation_strategy
      spot_instance_pools                      = max(floor(length(local.instance_types) / 2), 2)
    }
  }

  tag {
    key                 = "Role"
    value               = "eks-node"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/label/topology.kubernetes.io/zone"
    value               = each.key
    propagate_at_launch = false
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/label/topology.kubernetes.io/region"
    value               = data.aws_region.current.name
    propagate_at_launch = false
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/label/topology.kubernetes.io/region"
    value               = data.aws_region.current.name
    propagate_at_launch = false
  }

  dynamic "tag" {
    for_each = local.labels
    content {
      key                 = "k8s.io/cluster-autoscaler/node-template/label/${tag.key}"
      value               = tag.value
      propagate_at_launch = true
    }
  }

  dynamic "tag" {
    for_each = var.taints
    content {
      key                 = "k8s.io/cluster-autoscaler/node-template/taint/${tag.key}"
      value               = tag.value
      propagate_at_launch = true
    }
  }

  dynamic "tag" {
    for_each = local.tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = false
    }
  }

  depends_on = [aws_launch_template.config]
}
