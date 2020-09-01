locals {
  aws_ebs_csi_driver_iam_role_count = length(var.aws_ebs_csi_driver_iam_role_arn) == 0 && var.aws_ebs_csi_driver ? 1 : 0
  aws_ebs_csi_driver_iam_role_arn   = length(var.aws_ebs_csi_driver_iam_role_arn) > 0 ? var.aws_ebs_csi_driver_iam_role_arn : join("", aws_iam_role.aws_ebs_csi_driver.*.arn)
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

    principals {
      identifiers = [aws_iam_openid_connect_provider.cluster_oidc.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "aws_ebs_csi_driver" {
  count                = local.aws_ebs_csi_driver_iam_role_count
  name                 = "EksEBSCSIDriver-${var.name}"
  assume_role_policy   = data.aws_iam_policy_document.aws_ebs_csi_driver_assume_role_policy.json
  permissions_boundary = var.aws_ebs_csi_driver_iam_permissions_boundary
}

data "aws_iam_policy_document" "aws_ebs_csi_driver_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:AttachVolume",
      "ec2:CreateSnapshot",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:DeleteSnapshot",
      "ec2:DeleteTags",
      "ec2:DeleteVolume",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeSnapshots",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications",
      "ec2:DetachVolume",
      "ec2:ModifyVolume",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "aws_ebs_csi_driver" {
  count  = local.aws_ebs_csi_driver_iam_role_count
  name   = "aws_ebs_csi_driver"
  role   = aws_iam_role.aws_ebs_csi_driver[0].id
  policy = data.aws_iam_policy_document.aws_ebs_csi_driver_policy.json
}
