module "critical_addons_node_group" {
  source = "../asg_node_group"

  name           = "critical-addons"
  cluster_config = local.config

  max_size        = var.critical_addons_node_group_max_size
  min_size        = var.critical_addons_node_group_min_size
  instance_size   = var.critical_addons_node_group_instance_size
  instance_family = var.critical_addons_node_group_instance_family
  key_name        = var.critical_addons_node_group_key_name
  security_groups = var.critical_addons_node_group_security_groups
  architecture    = var.critical_addons_node_group_architecture

  bottlerocket                              = var.critical_addons_node_group_bottlerocket
  bottlerocket_admin_container_enabled      = var.critical_addons_node_group_bottlerocket_admin_container_enabled
  bottlerocket_admin_container_superpowered = var.critical_addons_node_group_bottlerocket_admin_container_superpowered
  bottlerocket_admin_container_source       = var.critical_addons_node_group_bottlerocket_admin_container_source

  zone_awareness = false
  taints = {
    "CriticalAddonsOnly" = "true:NoSchedule"
  }

  depends_on = [
    module.aws_auth
  ]
}

data "aws_region" "current" {}

// When upgrading k8s version run `aws eks describe-addon-versions --kubernetes-version <version>` to get addon_version numbers

resource "aws_eks_addon" "vpc-cni" {
  cluster_name      = local.config.name
  addon_name        = "vpc-cni"
  addon_version     = "v1.11.2-eksbuild.1"
  resolve_conflicts = "OVERWRITE"
}

resource "aws_eks_addon" "kube-proxy" {
  cluster_name      = local.config.name
  addon_name        = "kube-proxy"
  addon_version     = "v1.23.7-eksbuild.1"
  resolve_conflicts = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name      = local.config.name
  addon_name        = "coredns"
  addon_version     = "v1.8.7-eksbuild.2"
  resolve_conflicts = "OVERWRITE"
  depends_on = [
    module.critical_addons_node_group
  ]
}

resource "aws_eks_addon" "ebs-csi" {
  count                    = 1
  cluster_name             = local.config.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.10.0-eksbuild.1"
  service_account_role_arn = local.aws_ebs_csi_driver_iam_role_arn
  resolve_conflicts        = "OVERWRITE"
  depends_on = [
    module.critical_addons_node_group
  ]
}

module "cluster_autoscaler" {
  source = "./kubectl"
  config = local.config
  apply  = var.cluster_autoscaler
  manifest = templatefile(
    "${path.module}/addons/cluster-autoscaler.yaml",
    {
      cluster_name = var.name
      iam_role_arn = local.cluster_autoscaler_iam_role_arn
      aws_region   = data.aws_region.current.name
    }
  )
  depends_on = [
    module.critical_addons_node_group
  ]
}
