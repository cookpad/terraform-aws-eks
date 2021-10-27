provider "aws" {
  region              = "us-east-1"
  version             = "3.5.0"
  allowed_account_ids = ["214219211678"]
}

module "vpc" {
  source = "../../../modules/vpc"

  name               = var.vpc_name
  cidr_block         = var.cidr_block
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1d"]
  cluster_names      = var.cluster_names
}

module "iam" {
  source = "../../../modules/iam"
}
