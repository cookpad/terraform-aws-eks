module "critical_addons_node_group" {
  source = "../asg_node_group"

  cluster_config = local.config
  min_size       = 2
  max_size       = 3
  zone_awareness = false
  node_role      = "critical-addons"
  taints = {
    "CriticalAddonsOnly" = "true:NoSchedule"
  }
}

module "aws_node_termination_handler" {
  source = "./kubectl"
  config = local.config
  apply  = var.aws_node_termination_handler
  manifest = file("${path.module}/aws-node-termination-handler.yaml")
}

module "cluster_autoscaler" {
  source = "./kubectl"
  config = local.config
  apply  = var.cluster_autoscaler
  manifest = templatefile(
    "${path.module}/cluster-autoscaler.yaml",
    {
      cluster_name = var.name,
      iam_role_arn = local.cluster_autoscaler_iam_role_arn,
    }
  )
}

module "metrics_server" {
  source = "./kubectl"
  config = local.config
  apply  = var.metrics_server
  manifest = file("${path.module}/metrics-server.yaml")
}

module "prometheus_node_exporter" {
  source = "./kubectl"
  config = local.config
  apply  = var.prometheus_node_exporter
  manifest = file("${path.module}/prometheus-node-exporter.yaml")
}

locals {
  cluster_autoscaler_iam_role_count = length(var.cluster_autoscaler_iam_role_arn) == 0 && var.cluster_autoscaler ? 1 : 0
  cluster_autoscaler_iam_role_arn   = length(var.cluster_autoscaler_iam_role_arn) > 0 || ! var.cluster_autoscaler ? var.cluster_autoscaler_iam_role_arn : aws_iam_role.cluster_autoscaler[0].arn
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
  count              = local.cluster_autoscaler_iam_role_count
  name               = "EksClusterAutoscaler-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.cluster_autoscaler_assume_role_policy.json
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
