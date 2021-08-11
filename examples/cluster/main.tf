provider "aws" {
  region              = "us-east-1"
  version             = "3.53.0"
  allowed_account_ids = ["214219211678"]
}

module "cluster" {
  source = "../../modules/cluster"

  name = var.cluster_name

  vpc_config = data.terraform_remote_state.environment.outputs.vpc_config
  iam_config = data.terraform_remote_state.environment.outputs.iam_config

  envelope_encryption_enabled = false
  metrics_server              = true
  aws_ebs_csi_driver          = var.aws_ebs_csi_driver

  critical_addons_node_group_key_name = "development"


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
