output "kubeconfig" {
  value = data.template_file.kubeconfig.rendered
}

output "cluster_config" {
  value = {
    vpc_id              = var.vpc_id
    k8s_version         = aws_eks_cluster.control_plane.version
    name                = var.name
    node_security_group = aws_security_group.node.id
    private_subnet_ids  = var.private_subnet_ids
    node_iam_role       = var.node_iam_role
  }
}
