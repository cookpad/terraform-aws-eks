variable "name" {
  type = string
}

variable "eks_service_role" {
  type        = string
  default     = "eksServiceRole"
  description = "The service role to used by EKS"
}

variable "k8s_version" {
  default = "1.14"
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet ids for EKS"
}
