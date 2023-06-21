resource "aws_iam_role" "aws_ebs_csi_driver" {
  name               = "${var.iam_role_name_prefix}EksEBSCSIDriver-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.aws_ebs_csi_driver_assume_role_policy.json
  description        = "EKS CSI driver role for ${var.name} cluster"
}

data "aws_iam_policy_document" "aws_ebs_csi_driver_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster_oidc.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa", "system:serviceaccount:kube-system:ebs-snapshot-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster_oidc.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.cluster_oidc.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role_policy_attachment" "aws_ebs_csi_driver" {
  role       = aws_iam_role.aws_ebs_csi_driver.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
