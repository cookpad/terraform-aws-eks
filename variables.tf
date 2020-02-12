variable "name" {
  type = string
}

variable "vpc_config" {
  type = object({
    vpc_id             = string
    public_subnet_ids  = map(string)
    private_subnet_ids = map(string)
  })
}

variable "eks_service_role" {
  type        = string
  default     = "eksServiceRole"
  description = "The service role to used by EKS"
}

variable "node_iam_role" {
  type        = string
  default     = "EKSNode"
  description = "The IAM role used by nodes"
}

variable "k8s_version" {
  default = "1.14"
}

variable "endpoint_public_access" {
  type        = bool
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled."
  default     = false
}

variable "cluster_log_types" {
  type        = list(string)
  description = "A list of the desired control plane logging to enable."
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}
