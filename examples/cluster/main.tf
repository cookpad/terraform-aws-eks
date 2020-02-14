provider "aws" {
  region  = "us-east-1"
  version = "~> 2.47"
}

module "vpc" {
  source = "../../modules/vpc"

  name               = var.cluster_name
  cidr_block         = var.cidr_block
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

module "iam" {
  source = "../../modules/iam"

  eks_service_role_name = "eksServiceRole-${var.cluster_name}"
  eks_node_role_name    = "EKSNode-${var.cluster_name}"
}

module "eks_cluster" {
  source = "../../modules/cluster"
  name   = var.cluster_name

  vpc_config = module.vpc.config
  iam_config = module.iam.config

  # So we can access the k8s API from CI/dev
  endpoint_public_access = true
}

module "eks_node_group" {
  source = "../../modules/asg_node_group"

  cluster_config = module.eks_cluster.config
  asg_min_size   = 1
}
