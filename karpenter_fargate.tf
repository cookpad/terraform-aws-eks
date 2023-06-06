resource "aws_eks_fargate_profile" "karpenter" {
  cluster_name           = aws_eks_cluster.control_plane.name
  fargate_profile_name   = "Karpenter-${var.name}"
  pod_execution_role_arn =  aws_iam_role.karpenter_fargate.arn
  subnet_ids             = values(var.vpc_config.private_subnet_ids)

  selector {
    namespace = "karpenter"
    labels = {}
  }
}

resource "aws_iam_role" "karpenter_fargate" {
  name                 = "${var.iam_role_name_prefix}KarpenterFargate-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.fargate_assume_role_policy.json
  description = "Fargate execution role for Karpenter on ${var.name} eks cluster"
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

resource "aws_iam_role_policy_attachment" "karpenter_fargate_managed_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  ])

  role = aws_iam_role.karpenter_fargate.id
  policy_arn = each.value
}
