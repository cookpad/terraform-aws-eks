variable "name" {
  type        = string
  description = "A name for this eks cluster"
}

variable "endpoint_public_access" {
  type        = bool
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled."
  default     = false
}

variable "endpoint_public_access_cidrs" {
  type    = list(string)
  default = null
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

variable "iam_role_name_prefix" {
  default     = ""
  description = "An optional prefix to any IAM Roles created by this module"
}

variable "cluster_role_arn" {
  type        = string
  description = "The ARN of IAM role to be used by the cluster, if not specified a role will be created"
  default     = ""
}

variable "oidc_root_ca_thumbprints" {
  type        = list(string)
  default     = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  description = "Thumbprint of Root CA for EKS OpenID Connect (OIDC) identity provider, Valid until 2037 🤞"
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

variable "kms_cmk_arn" {
  type        = string
  default     = ""
  description = "The ARN of the KMS (CMK) customer master key, to be used for Envelope Encryption of Kubernetes secrets, if not set a key will be generated"
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

variable "security_group_ids" {
  type        = list(string)
  default     = []
  description = "A list of security group IDs for the cross-account elastic network interfaces that Amazon EKS creates to use to allow communication with the Kubernetes control plane. *WARNING* changes to this list will cause the cluster to be recreated."
}

variable "fargate_namespaces" {
  type        = set(string)
  default     = ["kube-system", "flux-system"]
  description = "A list of namespaces to create fargate profiles for, should be set to a list of namespaces critical for flux / cluster bootstrapping"
}

variable "vpc_cni_configuration_values" {
  type        = string
  default     = null
  description = "Configuration values passed to the vpc-cni EKS addon."
}

variable "kube_proxy_configuration_values" {
  type        = string
  default     = null
  description = "Configuration values passed to the kube-proxy EKS addon."
}

variable "coredns_configuration_values" {
  type        = string
  default     = "{ \"computeType\": \"fargate\" }"
  description = "Configuration values passed to the coredns EKS addon."
}

variable "ebs_csi_configuration_values" {
  type        = string
  default     = null
  description = "Configuration values passed to the ebs-csi EKS addon."
}
