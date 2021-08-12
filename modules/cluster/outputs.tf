locals {
  config = {
    name                  = aws_eks_cluster.control_plane.name
    endpoint              = aws_eks_cluster.control_plane.endpoint
    ca_data               = aws_eks_cluster.control_plane.certificate_authority[0].data
    vpc_id                = var.vpc_config.vpc_id
    private_subnet_ids    = var.vpc_config.private_subnet_ids
    node_security_group   = aws_eks_cluster.control_plane.vpc_config.0.cluster_security_group_id
    node_instance_profile = var.iam_config.node_role
    tags                  = var.tags
    aws_ebs_csi_driver    = var.aws_ebs_csi_driver
  }
}

output "config" {
  value = local.config
}

output "oidc_config" {
  value = {
    url       = aws_iam_openid_connect_provider.cluster_oidc.url
    arn       = aws_iam_openid_connect_provider.cluster_oidc.arn
    condition = "${replace(aws_iam_openid_connect_provider.cluster_oidc.url, "https://", "")}:sub"
  }
}
