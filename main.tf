module "vpc" {
  source = "./modules/vpc"

  name               = var.cluster_name
  cidr_block         = var.cidr_block
  availability_zones = var.availability_zones
}

module "iam" {
  source = "./modules/iam"

  eks_service_role_name = "eksServiceRole-${var.cluster_name}"
  eks_node_role_name    = "EKSNode-${var.cluster_name}"
}

module "cluster" {
  source = "./modules/cluster"

  name                   = var.cluster_name
  endpoint_public_access = var.endpoint_public_access

  vpc_config = module.vpc.config
  iam_config = module.iam.config
}

module "node_group" {
  source = "./modules/asg_node_group"

  cluster_config = module.cluster.config
  asg_min_size   = 1
}
