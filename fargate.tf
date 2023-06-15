resource "aws_eks_fargate_profile" "critical_pods" {
  cluster_name           = aws_eks_cluster.control_plane.name
  fargate_profile_name   = "${var.name}-critical-pods"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = values(var.vpc_config.private_subnet_ids)

  dynamic "selector" {
    for_each = var.fargate_namespaces

    content {
      namespace = selector.value
      labels    = {}
    }
  }
}

resource "aws_iam_role" "fargate" {
  name               = "${var.iam_role_name_prefix}Fargate-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.fargate_assume_role_policy.json
  description        = "Fargate execution role for pods on ${var.name} eks cluster"
}

data "aws_iam_policy_document" "fargate_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks-fargate-pods.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "fargate_managed_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  ])

  role       = aws_iam_role.fargate.id
  policy_arn = each.value
}
