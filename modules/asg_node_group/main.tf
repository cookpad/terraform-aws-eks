locals {
  preset_instance_families = {
    memory_optimized  = ["r5", "r5d", "r5n", "r5dn", "r5a", "r5ad"]
    general_purpose   = ["m5", "m5d", "m5n", "m5dn", "m5a", "m5ad"]
    compute_optimized = ["c5", "c5n", "c5d"]
    burstable         = ["t3", "t3a"]
  }
  preset_instance_types = [
    for instance_family in local.preset_instance_families[var.instance_family] : "${instance_family}.${var.instance_size}"
  ]
  instance_types = length(var.custom_instance_types) == 0 ? local.preset_instance_types : var.custom_instance_types
  name_prefix    = "eks-node-${var.cluster_config.name}-${replace(var.instance_family, "_", "-")}-${var.instance_size}-${replace(var.instance_lifecycle, "_", "-")}"
  node_role      = var.instance_lifecycle == "spot" ? "spot-worker" : "worker"
  labels         = merge({ "node-role.kubernetes.io/${local.node_role}" = "true" }, var.labels)
  asg_subnets    = var.zone_awareness ? { for az, subnet in var.cluster_config.private_subnet_ids : az => [subnet] } : { "multi-zone" = values(var.cluster_config.private_subnet_ids) }
  max_size       = floor(var.group_size / length(local.asg_subnets))
}

data "aws_ssm_parameter" "image_id" {
  name = "/aws/service/eks/optimized-ami/${var.cluster_config.k8s_version}/amazon-linux-2/recommended/image_id"
}

data "aws_ami" "image" {
  owners = ["amazon"]
  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.image_id.value]
  }
}

data "template_file" "cloud_config" {
  template = file("${path.module}/cloud_config.tpl")
  vars = {
    cluster_name = var.cluster_config.name
    labels       = join(",", [for label, value in local.labels : "${label}=${value}"])
    taints       = join(",", [for taint, value_effect in var.taints : "${taint}=${value_effect}"])
  }
}

data "template_cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/jinja2"
    content      = data.template_file.cloud_config.rendered
  }

  dynamic "part" {
    for_each = var.cloud_config
    content {
      content_type = "text/jinja2"
      content      = part.value
      merge_type   = "list(append)+dict(recurse_list)+str()"
    }
  }
}

resource "aws_launch_template" "config" {
  image_id               = data.aws_ami.image.id
  name                   = local.name_prefix
  vpc_security_group_ids = [var.cluster_config.node_security_group]
  user_data              = data.template_cloudinit_config.config.rendered

  instance_type = local.instance_types.0

  iam_instance_profile {
    name = var.cluster_config.node_instance_profile
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = var.root_volume_size
      volume_type = "gp2"
    }
  }

  block_device_mappings {
    device_name = "/dev/sdf"

    ebs {
      volume_size = var.docker_volume_size
      volume_type = "gp2"
    }
  }

  key_name = "development"
}

resource "aws_autoscaling_group" "nodes" {
  for_each = local.asg_subnets

  name                = "${local.name_prefix}-${each.key}"
  min_size            = var.min_size
  max_size            = local.max_size
  vpc_zone_identifier = each.value

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
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_config.name}"
    value               = "owned"
    propagate_at_launch = false
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_config.name}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "eks-node"
    propagate_at_launch = true
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

  depends_on = [aws_launch_template.config]
}
