provider "aws" {
  region              = "us-east-1"
  version             = "3.5.0"
  allowed_account_ids = ["214219211678"]
}

module "node_group" {
  source = "../../../modules/asg_node_group"

  cluster_config = data.terraform_remote_state.cluster.outputs.cluster_config

  name         = "standard-nodes"
  key_name     = "development"
  bottlerocket = true

  labels = {
    "cookpad.com/terraform-aws-eks-test-environment" = data.terraform_remote_state.cluster.outputs.cluster_name
  }
}
