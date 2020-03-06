locals {
  az_subnet_numbers = zipmap(var.availability_zones, range(0, length(var.availability_zones)))
}

resource "aws_subnet" "public" {
  for_each = local.az_subnet_numbers

  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.cidr_block, 6, each.value)
  vpc_id                  = aws_vpc.network.id
  map_public_ip_on_launch = true

  tags = {
    Name                             = "${var.name}-public-${each.key}"
    "kubernetes.io/role/elb"         = "1"
    "kubernetes.io/role/alb-ingress" = "1"
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, eks adds the kubernetes.io/cluster/${cluster_name} tag
      tags,
    ]
  }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private subnets
resource "aws_subnet" "private" {
  for_each = local.az_subnet_numbers

  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.cidr_block, 3, each.value + 1)
  vpc_id                  = aws_vpc.network.id
  map_public_ip_on_launch = false

  tags = {
    Name                              = "${var.name}-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/role/alb-ingress"  = "1"
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, eks adds the kubernetes.io/cluster/${cluster_name} tag
      tags,
    ]
  }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_default_route_table.private.id
}
