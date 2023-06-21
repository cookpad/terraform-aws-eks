locals {
  eks_cluster_role_arn = length(var.cluster_role_arn) == 0 ? aws_iam_role.eks_cluster_role[0].arn : var.cluster_role_arn
}

resource "aws_iam_role" "eks_cluster_role" {
  count              = length(var.cluster_role_arn) == 0 ? 1 : 0
  name               = "${var.iam_role_name_prefix}EksCluster-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role_policy.json

  # Resources running on the cluster are still generating logs when destroying the module resources
  # which results in the log group being re-created even after Terraform destroys it. Removing the
  # ability for the cluster role to create the log group prevents this log group from being re-created
  # outside of Terraform due to services still generating logs during destroy process
  inline_policy {
    name = "DenyLogGroupCreation"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["logs:CreateLogGroup"]
          Effect   = "Deny"
          Resource = "*"
        },
      ]
    })
  }
}

data "aws_iam_policy_document" "eks_assume_role_policy" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count      = length(var.cluster_role_arn) == 0 ? 1 : 0
  role       = aws_iam_role.eks_cluster_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
