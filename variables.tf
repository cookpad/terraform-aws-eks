variable "cluster_name" {
  type        = string
  description = "A name for the EKS cluster, and the resources it depends on"
}

variable "cluster_names" {
  type        = list(string)
  default     = []
  description = "Names of the EKS clusters deployed in the VPC."
}

variable "cidr_block" {
  type        = string
  description = "The CIDR block for the VPC that EKS will run in"
}

variable "availability_zones" {
  type        = list(string)
  description = "The availability zones to launch worker nodes in"
}

variable "aws_auth_role_map" {
  default     = []
  description = "A list of mappings from aws role arns to kubernetes users, and their groups"
}

variable "aws_auth_user_map" {
  default     = []
  description = "A list of mappings from aws user arns to kubernetes users, and their groups"
}

variable "envelope_encryption_enabled" {
  type        = bool
  default     = true
  description = "Should Cluster Envelope Encryption be enabled, if changed after provisioning - forces the cluster to be recreated"
}