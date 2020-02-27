module "critical_addons_node_group" {
  source = "../asg_node_group"

  cluster_config = local.config
  min_size       = 2
  max_size       = 3
  zone_awareness = false
  node_role      = "critical-addons"
  taints = {
    "CriticalAddonsOnly" = "true:NoSchedule"
  }
}

module "aws_node_termination_handler" {
  source = "./kubectl"
  config = local.config
  apply  = var.aws_node_termination_handler
  manifest = file("${path.module}/addons/aws-node-termination-handler.yaml")
}

data "aws_region" "current" {}

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
  source = "./kubectl"
  config = local.config
  apply  = var.metrics_server
  manifest = file("${path.module}/addons/metrics-server.yaml")
}

module "prometheus_node_exporter" {
  source = "./kubectl"
  config = local.config
  apply  = var.prometheus_node_exporter
  manifest = file("${path.module}/addons/prometheus-node-exporter.yaml")
}
