variable "name" {
  type = string
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

variable "vpc_config" {
  type = object({
    vpc_id             = string
    public_subnet_ids  = map(string)
    private_subnet_ids = map(string)
  })

  description = "The network configuration used by the cluster, If you use the included VPC module you can provide it's config output variable"
}

variable "iam_config" {
  type = object({
    service_role = string
    node_role    = string
  })

  default = {
    service_role = "eksServiceRole"
    node_role    = "EksNode"
  }

  description = "The IAM roles used by the cluster, If you use the included IAM module you can provide it's config output variable."
}

variable "oidc_root_ca_thumbprints" {
  type        = list(string)
  default     = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  description = "Thumbprint of Root CA for EKS OpenID Connect (OIDC) identity provider, Valid until 2037 🤞"
}

variable "cluster_autoscaler" {
  type        = bool
  default     = true
  description = "Should the cluster autoscaler be deployed"
}

variable "cluster_autoscaler_iam_role_arn" {
  type        = string
  default     = ""
  description = "The IAM role for the cluster_autoscaler, if omitted then an IAM role will be created"
}
