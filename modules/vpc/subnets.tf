locals {
  az_subnet_numbers = zipmap(var.availability_zones, range(0, length(var.availability_zones)))
  cluster_tags      = { for cluster_name in var.cluster_names : "kubernetes.io/cluster/${cluster_name}" => "shared" }
}

resource "aws_subnet" "public" {
  for_each = local.az_subnet_numbers

  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.cidr_block, 6, each.value)
  vpc_id                  = aws_vpc.network.id
  map_public_ip_on_launch = true

  tags = merge(
    local.cluster_tags,
    {
      Name                             = "${var.name}-public-${each.key}"
      "kubernetes.io/role/elb"         = "1"
      "kubernetes.io/role/alb-ingress" = "1"
    }
  )
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

  tags = merge(
    local.cluster_tags,
    {
      Name                              = "${var.name}-private-${each.key}"
      "kubernetes.io/role/internal-elb" = "1"
      "kubernetes.io/role/alb-ingress"  = "1"
    }
  )
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_default_route_table.private.id
}
