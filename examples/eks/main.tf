provider "aws" {
  region  = "us-east-1"
  version = "2.52.0"
}


module "eks" {
  source = "../../."

  cluster_name       = var.cluster_name
  cidr_block         = var.cidr_block
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
