locals {
  config = {
    name                  = aws_eks_cluster.control_plane.name
    endpoint              = aws_eks_cluster.control_plane.endpoint
    ca_data               = aws_eks_cluster.control_plane.certificate_authority[0].data
    vpc_id                = var.vpc_config.vpc_id
    private_subnet_ids    = var.vpc_config.private_subnet_ids
    node_security_group   = aws_eks_cluster.control_plane.vpc_config.0.cluster_security_group_id
    # this regular expression comes from the following link to retrieve role names
    # https://github.com/cookpad/terraform-aws-eks/pull/257/commits/99fae9b5dab1b2b2d2b1085a479f57d45e62e0ce
    node_instance_profile = regex("^arn:aws:iam::\\d+:role/*.*/(.+)?", var.iam_config.node_role_arn)[0]
    tags                  = var.tags
    dns_cluster_ip        = local.dns_cluster_ip
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
