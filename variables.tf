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

variable "endpoint_public_access" {
  type        = bool
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled."
  default     = false
}

variable "cluster_log_types" {
  type = list(string)
  description = "A list of the desired control plane logging to enable."
  default = ["api","audit","authenticator","controllerManager","scheduler"]
}
