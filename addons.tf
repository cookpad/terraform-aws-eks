resource "aws_eks_addon" "vpc-cni" {
  cluster_name         = aws_eks_cluster.control_plane.name
  addon_name           = "vpc-cni"
  addon_version        = local.versions.aws_ebs_csi_driver
  resolve_conflicts    = "OVERWRITE"
  configuration_values = var.critical_addons_vpc-cni_configuration_values
}

resource "aws_eks_addon" "kube-proxy" {
  cluster_name         = aws_eks_cluster.control_plane.name
  addon_name           = "kube-proxy"
  addon_version        = local.versions.kube_proxy
  resolve_conflicts    = "OVERWRITE"
  configuration_values = var.critical_addons_kube-proxy_configuration_values
}

resource "aws_eks_addon" "coredns" {
  cluster_name         = aws_eks_cluster.control_plane.name
  addon_name           = "coredns"
  addon_version        = local.versions.coredns
  resolve_conflicts    = "OVERWRITE"
  configuration_values = var.critical_addons_coredns_configuration_values
}

resource "aws_eks_addon" "ebs-csi" {
  count                    = 1
  cluster_name         = aws_eks_cluster.control_plane.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version        = local.versions.aws_ebs_csi_driver
  service_account_role_arn = aws_iam_role.aws_ebs_csi_driver.arn
  resolve_conflicts        = "OVERWRITE"
  configuration_values     = var.critical_addons_ebs-csi_configuration_values
}
