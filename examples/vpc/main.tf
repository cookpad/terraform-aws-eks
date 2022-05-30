terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.16.0"
    }
  }
}

provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["214219211678"]
}

module "vpc" {
  source = "../../modules/vpc"

  name               = var.vpc_name
  cidr_block         = var.cidr_block
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
