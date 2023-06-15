resource "aws_eks_addon" "vpc-cni" {
  cluster_name                = aws_eks_cluster.control_plane.name
  addon_name                  = "vpc-cni"
  addon_version               = local.versions.vpc_cni
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  configuration_values        = var.vpc_cni_configuration_values
}

resource "aws_eks_addon" "kube-proxy" {
  cluster_name                = aws_eks_cluster.control_plane.name
  addon_name                  = "kube-proxy"
  addon_version               = local.versions.kube_proxy
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  configuration_values        = var.kube_proxy_configuration_values
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.control_plane.name
  addon_name                  = "coredns"
  addon_version               = local.versions.coredns
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  configuration_values        = var.coredns_configuration_values
  depends_on                  = [aws_eks_fargate_profile.critical_pods]
}

resource "aws_eks_addon" "ebs-csi" {
  cluster_name                = aws_eks_cluster.control_plane.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = local.versions.aws_ebs_csi_driver
  service_account_role_arn    = aws_iam_role.aws_ebs_csi_driver.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  configuration_values        = var.ebs_csi_configuration_values
  depends_on                  = [aws_eks_fargate_profile.critical_pods]
}
