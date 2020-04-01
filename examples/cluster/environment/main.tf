provider "aws" {
  region              = "us-east-1"
  version             = "2.52.0"
  allowed_account_ids = ["214219211678"]
}

module "vpc" {
  source = "../../../modules/vpc"

  name               = var.cluster_name
  cidr_block         = var.cidr_block
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

module "iam" {
  source = "../../../modules/iam"

  service_role_name = "eksServiceRole-${var.cluster_name}"
  node_role_name    = "EKSNode-${var.cluster_name}"
}
