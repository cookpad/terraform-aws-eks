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
  user_data      = <<-YAML
  ## template: jinja
  #cloud-config
  fqdn: eks-node-${var.cluster_config.name}-{{ v1.instance_id }}
  fs_setup:
  # Create a filesystem on an attached EBS volume. Only one of them should succeed.
  - device: /dev/nvme0n1
    filesystem: ext4
    label: docker-vol
    partition: none
  - device: /dev/nvme1n1
    filesystem: ext4
    label: docker-vol
    partition: none
  - device: /dev/xvdf
    filesystem: ext4
    label: docker-vol
    partition: none
  mounts:
  - [/dev/disk/by-label/docker-vol, /var/lib/docker, ext4, "defaults,noatime", 0, 0]
  runcmd:
  - [aws, --region={{ v1.region }}, ec2, create-tags, --resources={{ v1.instance_id }}, "--tags=Key=Name,Value=eks-node-${var.cluster_config.name}-{{ v1.instance_id }}"]
  - [systemctl, restart, docker]
  - [/etc/eks/bootstrap.sh, ${var.cluster_config.name}]
  YAML
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

resource "aws_launch_template" "config" {
  image_id               = data.aws_ami.image.id
  name                   = local.name_prefix
  vpc_security_group_ids = [var.cluster_config.node_security_group]
  user_data              = base64encode(local.user_data)

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

resource "aws_autoscaling_group" "nodes" {
  for_each = var.cluster_config.private_subnet_ids

  name                = "${local.name_prefix}-${each.key}"
  min_size            = var.asg_min_size
  max_size            = local.max_size
  vpc_zone_identifier = [each.value]

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
