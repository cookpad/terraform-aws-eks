provider "aws" {
  region  = "us-east-2"
  version = "~> 2.47"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

module "eks_cluster" {
  source     = "../../."
  name       = var.cluster_name
  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnet_ids.default.ids
}
