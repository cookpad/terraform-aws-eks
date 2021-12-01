terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.53.0"
    }
  }
}

provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["214219211678"]
}

module "node_group" {
  source = "../../../modules/asg_node_group"

  cluster_config = data.terraform_remote_state.cluster.outputs.cluster_config

  name     = "standard-nodes"
  key_name = "development"

  labels = {
    "cookpad.com/terraform-aws-eks-test-environment" = data.terraform_remote_state.cluster.outputs.cluster_name
  }
}
