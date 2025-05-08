provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["214219211678"]
}

#trivy:ignore:AVD-AWS-0178 trivy:ignore:AVD-AWS-0164
module "vpc" {
  source = "../../../modules/vpc"

  name               = var.vpc_name
  cidr_block         = var.cidr_block
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1d"]
}
