provider "aws" {
  region  = "us-east-1"
  version = "~> 2.47"
}

module "vpc" {
  source = "../../vpc"

  name               = var.vpc_name
  cidr_block         = "10.0.0.0/18"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
