module "critical_addons_nodes" {
  source = "../asg_node_group"

  cluster_config = local.config
  min_size       = 2
  zone_awareness = false
  node_role      = "critical-addons"
  taints = {
    "CriticalAddonsOnly" = "true:NoSchedule"
  }
}
