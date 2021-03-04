module "critical_addons_node_group" {
  source = "../asg_node_group"

  name           = "critical-addons"
  cluster_config = local.config

  max_size        = var.critical_addons_node_group_max_size
  min_size        = var.critical_addons_node_group_min_size
  instance_size   = var.critical_addons_node_group_instance_size
  instance_family = var.critical_addons_node_group_instance_family
  cloud_config    = var.critical_addons_node_group_cloud_config
  key_name        = var.critical_addons_node_group_key_name
  security_groups = var.critical_addons_node_group_security_groups

  bottlerocket                              = var.critical_addons_node_group_bottlerocket
  bottlerocket_admin_container_enabled      = var.critical_addons_node_group_bottlerocket_admin_container_enabled
  bottlerocket_admin_container_superpowered = var.critical_addons_node_group_bottlerocket_admin_container_superpowered
  bottlerocket_admin_container_source       = var.critical_addons_node_group_bottlerocket_admin_container_source

  zone_awareness = false
  taints = {
    "CriticalAddonsOnly" = "true:NoSchedule"
  }
}

data "aws_region" "current" {}

module "aws_k8s_cni" {
  source = "./kubectl"
  config = local.config
  manifest = templatefile(
    "${path.module}/addons/aws-k8s-cni.yaml",
    { aws_region = data.aws_region.current.name }
  )
}

data "aws_vpc" "network" {
  id = var.vpc_config.vpc_id
}

locals {
  dns_cluster_ip = length(var.dns_cluster_ip) > 0 ? var.dns_cluster_ip : (split(".", data.aws_vpc.network.cidr_block)[0] == "10" ? "172.20.0.10" : "10.100.0.10")
}

module "coredns" {
  source = "./kubectl"
  config = local.config
  manifest = templatefile(
    "${path.module}/addons/coredns.yaml",
    {
      aws_region     = data.aws_region.current.name
      dns_cluster_ip = local.dns_cluster_ip
    },
  )
}

module "kube_proxy" {
  source = "./kubectl"
  config = local.config
  manifest = templatefile(
    "${path.module}/addons/kube-proxy.yaml",
    { aws_region = data.aws_region.current.name },
  )
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
}

module "metrics_server" {
  source   = "./kubectl"
  config   = local.config
  apply    = var.metrics_server
  manifest = file("${path.module}/addons/metrics-server.yaml")
  replace  = true
}

module "pod_nanny" {
  source   = "./kubectl"
  config   = local.config
  apply    = var.metrics_server
  manifest = file("${path.module}/addons/pod-nanny.yaml")
}

module "aws_node_termination_handler" {
  source   = "./kubectl"
  config   = local.config
  apply    = var.aws_node_termination_handler
  manifest = file("${path.module}/addons/aws-node-termination-handler.yaml")
  replace  = true
}

module "prometheus_node_exporter" {
  source   = "./kubectl"
  config   = local.config
  apply    = var.prometheus_node_exporter
  manifest = file("${path.module}/addons/prometheus-node-exporter.yaml")
}

module "nvidia_device_plugin" {
  source   = "./kubectl"
  config   = local.config
  apply    = var.nvidia_device_plugin
  manifest = file("${path.module}/addons/nvidia-device-plugin.yaml")
  replace  = true
}

module "aws_ebs_csi_driver" {
  source = "./kubectl"
  config = local.config
  apply  = var.aws_ebs_csi_driver
  manifest = templatefile(
    "${path.module}/addons/aws-ebs-csi-driver.yaml",
    { iam_role_arn = local.aws_ebs_csi_driver_iam_role_arn }
  )
}

module "aws_load_balancer_controller_crds" {
  source   = "./kubectl"
  config   = local.config
  apply    = var.aws_load_balancer_controller
  manifest = file("${path.module}/addons/aws-load-balancer-controller-crds.yaml")
}

module "aws_load_balancer_controller" {
  source = "./kubectl"
  config = local.config
  apply  = var.aws_load_balancer_controller
  manifest = templatefile(
    "${path.module}/addons/aws-load-balancer-controller.yaml",
    {
      iam_role_arn = local.aws_load_balancer_controller_iam_role_arn,
      cluster_name = var.name,
      vpc_id       = var.vpc_config.vpc_id,
      aws_region   = data.aws_region.current.name,
    }
  )
}
