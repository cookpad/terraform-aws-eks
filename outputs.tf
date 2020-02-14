output "kubeconfig" {
  value = data.template_file.kubeconfig.rendered
}

output "config" {
  value = {
    name                  = var.name
    k8s_version           = aws_eks_cluster.control_plane.version
    vpc_id                = var.vpc_config.vpc_id
    private_subnet_ids    = var.vpc_config.private_subnet_ids
    node_security_group   = aws_security_group.node.id
    node_instance_profile = var.iam_config.node_role
  }
}
