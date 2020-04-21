# In the test we provision the network and IAM resources using the environment
# module, we then lookup the relevant config here!
# This is in order to simulate launching a cluster in an existing VPC!

locals {
  availability_zones = toset(["us-east-1a", "us-east-1b", "us-east-1d"])
  vpc_config = {
    vpc_id             = data.aws_vpc.network.id
    public_subnet_ids  = { for subnet in data.aws_subnet.public : subnet.availability_zone => subnet.id }
    private_subnet_ids = { for subnet in data.aws_subnet.private : subnet.availability_zone => subnet.id }
  }

  iam_config = {
    service_role = "eksServiceRole-${var.cluster_name}"
    node_role    = "EKSNode-${var.cluster_name}"
  }
}

data "aws_vpc" "network" {
  tags = {
    Name = var.cluster_name
  }
}

data "aws_subnet" "public" {
  for_each = local.availability_zones

  availability_zone = each.value
  vpc_id            = data.aws_vpc.network.id
  tags = {
    Name = "${var.cluster_name}-public-${each.value}"
  }
}

data "aws_subnet" "private" {
  for_each = local.availability_zones

  availability_zone = each.value
  vpc_id            = data.aws_vpc.network.id
  tags = {
    Name = "${var.cluster_name}-private-${each.value}"
  }
}
