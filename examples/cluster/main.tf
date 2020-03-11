provider "aws" {
  region  = "us-east-1"
  version = "2.52.0"
}

data "aws_vpc" "network" {
  tags = {
    Name = var.cluster_name
  }
}

locals {
  availability_zones = toset(["us-east-1a", "us-east-1b", "us-east-1c"])
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

module "cluster" {
  source = "../../modules/cluster"

  name = var.cluster_name

  vpc_config = {
    vpc_id = data.aws_vpc.network.id
    public_subnet_ids = {
      us-east-1a = data.aws_subnet.public["us-east-1a"].id
      us-east-1b = data.aws_subnet.public["us-east-1b"].id
      us-east-1c = data.aws_subnet.public["us-east-1c"].id
    }
    private_subnet_ids = {
      us-east-1a = data.aws_subnet.private["us-east-1a"].id
      us-east-1b = data.aws_subnet.private["us-east-1b"].id
      us-east-1c = data.aws_subnet.private["us-east-1c"].id
    }
  }

  iam_config = {
    service_role = "eksServiceRole-${var.cluster_name}"
    node_role    = "EKSNode-${var.cluster_name}"
    admin_role   = "EKSAdmin-${var.cluster_name}"
  }

  aws_auth_role_map = [
    {
      username = aws_iam_role.test_role.name
      rolearn  = aws_iam_role.test_role.arn
      groups   = ["system:masters"]
    }
  ]
}

module "node_group" {
  source = "../../modules/asg_node_group"

  cluster_config = module.cluster.config

  labels = {
    "cookpad.com/terraform-aws-eks-test-environment" = var.cluster_name
  }

  taints = {
    "terraform-aws-eks" = "test:PreferNoSchedule"
  }
}
