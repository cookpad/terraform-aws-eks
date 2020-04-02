resource "aws_iam_role" "terraform" {
  name = "Terraform"

  assume_role_policy = data.aws_iam_policy_document.terraform_assume_role.json
}

data "aws_caller_identity" "current" {}

# assume role policy data
data "aws_iam_policy_document" "terraform_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role_policy" "manipulate_resources" {
  name   = "ManipulateAWSResources"
  role   = aws_iam_role.terraform.id
  policy = data.aws_iam_policy_document.manipulate_resources.json
}

data "aws_iam_policy_document" "manipulate_resources" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "iam:*",
      "kms:*",
      "logs:*",
      "ec2:*",
      "eks:*",
      "autoscaling:*",
      "ssm:GetParameter"
    ]
  }
}
