variable "vpc_name" {
  type    = string
  default = "terraform-aws-eks-test-environment"
}

variable "cidr_block" {
  type    = string
  default = "10.0.0.0/18"
}
