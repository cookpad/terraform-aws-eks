variable "cluster_name" {
  type        = string
  description = "A name for the EKS cluster, and the resources it depends on"
}

variable "cidr_block" {
  type        = string
  description = "The CIDR block for the VPC that EKS will run in"
}

variable "availability_zones" {
  type        = list(string)
  description = "The availability zones to launch worker nodes in"
}

variable "endpoint_public_access" {
  type        = bool
  description = "Indicates whether or not the EKS public API server endpoint is enabled."
  default     = false
}

variable "node_labels" {
  type        = map(string)
  default     = {}
  description = "labels that will be added to the kubernetes node"
}
