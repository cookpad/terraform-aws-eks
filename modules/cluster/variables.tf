variable "name" {
  type = string
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

variable "aws_ebs_csi_driver" {
  type        = bool
  default     = false
  description = "Should the Amazon Elastic Block Store (EBS) CSI driver be deployed"
}

variable "aws_ebs_csi_driver_iam_role_arn" {
  type        = string
  default     = ""
  description = "The IAM role for the Amazon Elastic Block Store (EBS) CSI driver, if omitted then an IAM role will be created"
}

variable "aws_ebs_csi_driver_iam_permissions_boundary" {
  type        = string
  default     = ""
  description = "The ARN of the policy that is used to set the permissions boundary for the role."
}

variable "pv_fstype" {
  type        = string
  default     = "ext4"
  description = "File system type that will be formatted during volume creation, (xfs, ext2, ext3 or ext4)"
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

variable "critical_addons_node_group_min_size" {
  type        = number
  default     = 2
  description = "The minimum number of instances that will be launched by this group, if not a multiple of the number of AZs in the group, may be rounded up"
}

variable "critical_addons_node_group_max_size" {
  type        = number
  default     = 3
  description = "The maximum number of instances that will be launched by this group, if not a multiple of the number of AZs in the group, may be rounded down"
}

variable "critical_addons_node_group_instance_size" {
  type        = string
  default     = "large"
  description = "The size of instances in this node group"
}

variable "critical_addons_node_group_instance_family" {
  type        = string
  default     = "general_purpose"
  description = "The family of instances that this group will launch, should be one of: memory_optimized, general_purpose, compute_optimized or burstable. Defaults to general_purpose"
}

variable "critical_addons_node_group_key_name" {
  type    = string
  default = ""
}

variable "critical_addons_node_group_security_groups" {
  type        = list(string)
  default     = []
  description = "Additional security groups for the nodes"
}

variable "critical_addons_node_group_bottlerocket" {
  type        = bool
  default     = false
  description = "Use Bottlerocket OS, rather than Amazon Linux for the critical addons node group"
}

variable "critical_addons_node_group_bottlerocket_admin_container_enabled" {
  type        = bool
  default     = false
  description = "Should the bottlerocket admin container (for ssh access) be enabled by default"
}

variable "critical_addons_node_group_bottlerocket_admin_container_superpowered" {
  type        = bool
  default     = true
  description = "Whether the admin container has high levels of access to the Bottlerocket host."
}

variable "critical_addons_node_group_bottlerocket_admin_container_source" {
  type        = string
  default     = ""
  description = "URI of a custom admin container image"
}

variable "security_group_ids" {
  type        = list(string)
  default     = []
  description = "A list of security group IDs for the cross-account elastic network interfaces that Amazon EKS creates to use to allow communication with the Kubernetes control plane. *WARNING* changes to this list will cause the cluster to be recreated."
}
