variable "vpc_name" {
  type    = string
  default = "terraform-aws-eks-test-environment"
}

variable "cidr_block" {
  type    = string
  default = "10.0.0.0/18"
}

variable "cluster_names" {
  description = "Names of the EKS clusters deployed in this VPC."
  type        = list(string)
  default     = []
}
