provider "aws" {
  region  = "us-east-1"
  version = "2.49.0"
}


module "eks" {
  source = "../../."

  cluster_name       = var.cluster_name
  cidr_block         = var.cidr_block
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  # So we can access the k8s API from CI/dev
  endpoint_public_access = true

  node_labels = {
    "cookpad.com/terraform-aws-eks-test-environment" = var.cluster_name
  }

  node_taints = {
    "terraform-aws-eks" = "test:PreferNoSchedule"
  }

  aws_auth_role_map = [
    {
      username = aws_iam_role.test_role.name
      rolearn  = aws_iam_role.test_role.arn
      groups   = ["system:masters"]
    }
  ]
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "test_role" {
  name_prefix        = "TerraformAWSEKS"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": "${data.aws_caller_identity.current.arn}"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
