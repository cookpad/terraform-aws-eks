provider "aws" {
  region  = "us-east-1"
  version = "~> 2.47"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id

  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }
}

module "eks_cluster" {
  source     = "../../."
  name       = var.cluster_name
  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnet_ids.default.ids

  # So we can access the k8s API from CI/dev
  endpoint_public_access = true
}

module "eks_node_group" {
  source = "../../asg_node_group"

  cluster_config = module.eks_cluster.cluster_config
  asg_min_size   = 1
}
