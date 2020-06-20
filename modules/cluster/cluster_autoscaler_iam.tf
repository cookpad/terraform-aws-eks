locals {
  cluster_autoscaler_iam_role_count = length(var.cluster_autoscaler_iam_role_arn) == 0 && var.cluster_autoscaler ? 1 : 0
  cluster_autoscaler_iam_role_arn   = length(var.cluster_autoscaler_iam_role_arn) > 0 ? var.cluster_autoscaler_iam_role_arn : join("", aws_iam_role.cluster_autoscaler.*.arn)
}

data "aws_iam_policy_document" "cluster_autoscaler_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster_oidc.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.cluster_oidc.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "cluster_autoscaler" {
  count                = local.cluster_autoscaler_iam_role_count
  name                 = "EksClusterAutoscaler-${var.name}"
  assume_role_policy   = data.aws_iam_policy_document.cluster_autoscaler_assume_role_policy.json
  permissions_boundary = var.cluster_autoscaler_iam_permissions_boundary
}

data "aws_iam_policy_document" "cluster_autoscaler_policy" {
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
    ]
    resources = ["*"]
  }
}
resource "aws_iam_role_policy" "cluster_autoscaler" {
  count  = local.cluster_autoscaler_iam_role_count
  name   = "cluster_autoscaler"
  role   = aws_iam_role.cluster_autoscaler[0].id
  policy = data.aws_iam_policy_document.cluster_autoscaler_policy.json
}
