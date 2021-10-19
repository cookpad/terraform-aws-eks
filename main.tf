module "vpc" {
  source = "./modules/vpc"

  name               = var.cluster_name
  cidr_block         = var.cidr_block
  availability_zones = var.availability_zones
  cluster_names      = var.cluster_names
}

module "iam" {
  source = "./modules/iam"

  service_role_name = "eksServiceRole-${var.cluster_name}"
  node_role_name    = "EKSNode-${var.cluster_name}"
}

module "cluster" {
  source = "./modules/cluster"

  name = var.cluster_name

  vpc_config = module.vpc.config
  iam_config = module.iam.config

  aws_auth_role_map = var.aws_auth_role_map
  aws_auth_user_map = var.aws_auth_user_map
}

module "node_group" {
  source = "./modules/asg_node_group"

  cluster_config = module.cluster.config
}
