locals {
  preset_instance_families = {
    memory_optimized  = ["r5", "r5n", "r5a", "r4"]
    general_purpose   = ["m5", "m5n", "m5a", "t3", "m4"]
    compute_optimized = ["c5", "c5n", "c4"]
  }
  preset_instance_types = [
    for instance_family in local.preset_instance_families[var.instance_family] : "${instance_family}.${var.instance_size}"
  ]
  instance_types = (length(var.custom_instance_types) == 0 ? local.preset_instance_types : var.custom_instance_types)
  max_size       = floor(var.group_size / length(var.cluster_config.private_subnet_ids))
  name_prefix    = "eks-node-${var.cluster_config.name}-${replace(var.instance_family, "_", "-")}-${var.instance_size}-${replace(var.instance_lifecycle, "_", "-")}"
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
    for_each = var.cloud_config_extra
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
    name = var.cluster_config.node_iam_role
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

data "aws_subnet" "nodes" {
  for_each = var.cluster_config.private_subnet_ids
  id       = each.value
}

resource "aws_autoscaling_group" "nodes" {
  for_each = data.aws_subnet.nodes

  name                = "${local.name_prefix}-${each.value.availability_zone}"
  min_size            = var.asg_min_size
  max_size            = local.max_size
  vpc_zone_identifier = [each.value.id]

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
      spot_instance_pools                      = var.spot_instance_pools
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

  depends_on = [aws_launch_template.config]
}
