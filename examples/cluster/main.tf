provider "aws" {
  region              = "us-east-1"
  version             = "2.52.0"
  allowed_account_ids = ["214219211678"]
}

module "cluster" {
  source = "../../modules/cluster"

  name = var.cluster_name

  vpc_config = local.vpc_config
  iam_config = local.iam_config

  aws_auth_role_map = [
    {
      username = aws_iam_role.test_role.name
      rolearn  = aws_iam_role.test_role.arn
      groups   = ["system:masters"]
    }
  ]
}

module "node_group" {
  source = "../../modules/asg_node_group"

  cluster_config = module.cluster.config

  labels = {
    "cookpad.com/terraform-aws-eks-test-environment" = var.cluster_name
  }

  taints = {
    "terraform-aws-eks" = "test:PreferNoSchedule"
  }
}
