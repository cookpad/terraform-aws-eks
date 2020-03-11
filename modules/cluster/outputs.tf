locals {
  config = {
    name                  = aws_eks_cluster.control_plane.name
    k8s_version           = aws_eks_cluster.control_plane.version
    endpoint              = aws_eks_cluster.control_plane.endpoint
    ca_data               = aws_eks_cluster.control_plane.certificate_authority[0].data
    vpc_id                = var.vpc_config.vpc_id
    private_subnet_ids    = var.vpc_config.private_subnet_ids
    node_security_group   = aws_security_group.node.id
    node_instance_profile = var.iam_config.node_role
    admin_role_arn        = data.aws_iam_role.admin_role.arn
  }
}

output "config" {
  value = local.config
}

output "odic_config" {
  value = {
    url       = aws_iam_openid_connect_provider.cluster_oidc.url
    arn       = aws_iam_openid_connect_provider.cluster_oidc.arn
    condition = "${replace(aws_iam_openid_connect_provider.cluster_oidc.url, "https://", "")}:sub"
  }
}
