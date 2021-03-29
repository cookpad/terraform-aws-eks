resource "aws_vpc" "network" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  tags = merge(
    local.cluster_tags,
    {
      Name = var.name
    }
  )

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags: eks adds the kubernetes.io/cluster/${cluster_name} tag
      tags,
    ]
  }
}

# Internet gateway
resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.network.id

  tags = {
    Name = var.name
  }
}

# NAT gateway
resource "aws_eip" "nat_gateway" {
  vpc        = true
  depends_on = [aws_internet_gateway.gateway]

  tags = {
    Name = "${var.name}-nat-gateway"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.public[var.availability_zones[0]].id

  tags = {
    Name = var.name
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.network.id

  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_route" "internet-gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gateway.id
}

resource "aws_default_route_table" "private" {
  default_route_table_id = aws_vpc.network.default_route_table_id

  tags = {
    Name = "${var.name}-private"
  }
}

resource "aws_route" "nat-gateway" {
  route_table_id         = aws_default_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}
