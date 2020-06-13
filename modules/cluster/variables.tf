variable "name" {
  type = string
}

variable "k8s_version" {
  default = "1.16"
}

variable "endpoint_public_access" {
  type        = bool
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled."
  default     = true
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
    node_role    = "EKSNode"
  }

  description = "The IAM roles used by the cluster, If you use the included IAM module you can provide it's config output variable."
}

variable "cluster_autoscaler_iam_permissions_boundary" {
  type        = string
  default     = ""
  description = "The ARN of the policy that is used to set the permissions boundary for the role."
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

variable "metrics_server" {
  type        = bool
  default     = false
  description = "Should the metrics server be deployed"
}

variable "aws_node_termination_handler" {
  type        = bool
  default     = true
  description = "Should the AWS node termination handler be deployed"
}

variable "prometheus_node_exporter" {
  type        = bool
  default     = false
  description = "Should the prometheus node exporter be deployed"
}

variable "aws_auth_role_map" {
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default     = []
  description = "A list of mappings from aws role arns to kubernetes users, and their groups"
}

variable "aws_auth_user_map" {
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default     = []
  description = "A list of mappings from aws user arns to kubernetes users, and their groups"
}

variable "envelope_encryption_enabled" {
  type        = bool
  default     = true
  description = "Should Cluster Envelope Encryption be enabled, if changed after provisioning - forces the cluster to be recreated"
}

variable "kms_cmk_arn" {
  type        = string
  default     = ""
  description = "The ARN of the KMS (CMK) customer master key, to be used for Envelope Encryption of Kubernetes secrets, if not set a key will be generated"
}

variable "nvidia_device_plugin" {
  type        = bool
  default     = true
  description = "Should the nvidia device plugin be installed, required for GPU nodes"
}

variable "legacy_security_groups" {
  type        = bool
  default     = false
  description = "Preserves existing security group setup from pre 1.15 clusters, to allow existing clusters to be upgraded without recreation"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A map of tags to assign to cluster AWS resources"
}

variable "dns_cluster_ip" {
  type        = string
  default     = ""
  description = "Overrides the IP address to use for DNS queries within the cluster. Defaults to 10.100.0.10 or 172.20.0.10 based on the VPC cidr"
}
