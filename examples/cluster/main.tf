terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.47.0"
    }
  }
}

provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["214219211678"]
}

data "http" "ip" {
  url = "http://ipv4.icanhazip.com"
}

module "cluster" {
  source = "../../modules/cluster"

  name = var.cluster_name

  vpc_config = data.terraform_remote_state.environment.outputs.vpc_config
  iam_config = data.terraform_remote_state.environment.outputs.iam_config

  aws_ebs_csi_driver = var.aws_ebs_csi_driver

  critical_addons_node_group_key_name = "development"

  critical_addons_coredns_configuration_values = jsonencode({ replicaCount = 3 })
  critical_addons_ebs-csi_configuration_values = jsonencode({ node = { tolerateAllTaints = true } })
  endpoint_public_access                       = true
  endpoint_public_access_cidrs                 = ["${chomp(data.http.ip.body)}/32"]


  aws_auth_role_map = [
    {
      username = aws_iam_role.test_role.name
      rolearn  = aws_iam_role.test_role.arn
      groups   = ["system:masters"]
    }
  ]

  tags = {
    Project = "terraform-aws-eks"
  }
}
