resource "aws_iam_role" "karpenter_controller" {
  name               = "${var.cluster_config.iam_role_name_prefix}Karpenter-${var.cluster_config.name}"
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_assume_role_policy.json
  description        = "Karpenter controller role for ${var.cluster_config.name} cluster"
}

data "aws_iam_policy_document" "karpenter_controller_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_config.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:karpenter:karpenter"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_config.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [var.oidc_config.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role_policy" "karpenter_controller" {
  name   = "KarpenterController"
  role   = aws_iam_role.karpenter_controller.id
  policy = data.aws_iam_policy_document.karpenter_controller.json
}

data "aws_iam_policy_document" "karpenter_controller" {
  statement {
    sid    = "AllowScopedEC2InstanceActions"
    effect = "Allow"

    # tfsec:ignore:aws-iam-no-policy-wildcards
    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}::image/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}::snapshot/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:*:spot-instances-request/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:*:security-group/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:*:subnet/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:*:launch-template/*",
    ]

    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet",
    ]
  }

  statement {
    sid    = "AllowScopedEC2InstanceActionsWithTags"
    effect = "Allow"

    # tfsec:ignore:aws-iam-no-policy-wildcards
    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:*:fleet/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:*:instance/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:*:volume/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:*:network-interface/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:*:launch-template/*",
    ]

    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${var.cluster_config.name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.sh/provisioner-name"
      values   = ["*"]
    }
  }

  statement {
    sid    = "AllowScopedResourceCreationTagging"
    effect = "Allow"

    # tfsec:ignore:aws-iam-no-policy-wildcards
    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:*:fleet/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:*:instance/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:*:volume/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:*:network-interface/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:*:launch-template/*",
    ]

    actions = ["ec2:CreateTags"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${var.cluster_config.name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"

      values = [
        "RunInstances",
        "CreateFleet",
        "CreateLaunchTemplate",
      ]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.sh/provisioner-name"
      values   = ["*"]
    }
  }

  statement {
    sid    = "AllowMachineMigrationTagging"
    effect = "Allow"
    # tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:*:instance/*"]
    actions   = ["ec2:CreateTags"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_config.name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/karpenter.sh/managed-by"
      values   = [var.cluster_config.name]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.sh/provisioner-name"
      values   = ["*"]
    }

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "aws:TagKeys"

      values = [
        "karpenter.sh/provisioner-name",
        "karpenter.sh/managed-by",
      ]
    }
  }

  statement {
    sid    = "AllowScopedDeletion"
    effect = "Allow"

    # tfsec:ignore:aws-iam-no-policy-wildcards
    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:*:instance/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:*:launch-template/*",
    ]

    actions = [
      "ec2:TerminateInstances",
      "ec2:DeleteLaunchTemplate",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_config.name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/provisioner-name"
      values   = ["*"]
    }
  }

  statement {
    sid       = "AllowRegionalReadActions"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [data.aws_region.current.name]
    }
  }

  statement {
    sid       = "AllowSSMReadActions"
    effect    = "Allow"
    resources = ["arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.name}::parameter/aws/service/*"]
    actions   = ["ssm:GetParameter"]
  }

  statement {
    sid       = "AllowPricingReadActions"
    effect    = "Allow"
    resources = ["*"]
    actions   = ["pricing:GetProducts"]
  }

  statement {
    sid       = "AllowInterruptionQueueActions"
    effect    = "Allow"
    resources = [aws_sqs_queue.karpenter_interruption.arn]

    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
    ]
  }

  statement {
    sid       = "AllowPassingInstanceRole"
    effect    = "Allow"
    resources = [aws_iam_role.karpenter_node.arn]
    actions   = ["iam:PassRole"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  statement {
    sid       = "AllowAPIServerEndpointDiscovery"
    effect    = "Allow"
    resources = [var.cluster_config.arn]
    actions   = ["eks:DescribeCluster"]
  }
}
