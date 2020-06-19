module "critical_addons_node_group" {
  source = "../asg_node_group"

  name           = "critical-addons"
  cluster_config = local.config

  key_name         = var.critical_addons_node_group_key_name
  min_size         = var.critical_addons_node_group_min_size
  max_size         = var.critical_addons_node_group_max_size
  desired_capacity = var.critical_addons_node_group_desired_capacity
  instance_family  = var.critical_addons_node_group_instance_family
  instance_size    = var.critical_addons_node_group_instance_size
  security_groups  = var.critical_addons_node_group_security_groups

  zone_awareness = false
  taints = {
    "CriticalAddonsOnly" = "true:NoSchedule"
  }
}

data "aws_region" "current" {}

module "aws_k8s_cni" {
  source   = "./kubectl"
  config   = local.config
  manifest = file("${path.module}/addons/aws-k8s-cni.yaml")
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
  manifest = file("${path.module}/addons/nvidia-device-plugin.yml")
}
