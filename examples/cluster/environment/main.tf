provider "aws" {
  region  = "us-east-1"
  version = "2.52.0"
}

module "vpc" {
  source = "../../../modules/vpc"

  name               = var.cluster_name
  cidr_block         = var.cidr_block
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

module "iam" {
  source = "../../../modules/iam"

  eks_service_role_name = "eksServiceRole-${var.cluster_name}"
  eks_node_role_name    = "EKSNode-${var.cluster_name}"
}
