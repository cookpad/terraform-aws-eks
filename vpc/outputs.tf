output "config" {
  value = {
    vpc_id             = aws_vpc.network.id
    public_subnet_ids  = { for az, subnet in aws_subnet.public : az => subnet.id }
    private_subnet_ids = { for az, subnet in aws_subnet.private : az => subnet.id }
  }
}
