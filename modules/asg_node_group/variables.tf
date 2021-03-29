variable "cluster_config" {
  type = object({
    name                  = string
    endpoint              = string
    ca_data               = string
    vpc_id                = string
    private_subnet_ids    = map(string)
    node_security_group   = string
    node_instance_profile = string
    tags                  = map(string)
    dns_cluster_ip        = string
    aws_ebs_csi_driver    = bool
  })
}

variable "k8s_version" {
  default = "1.19"
}

variable "name" {
  type        = string
  default     = ""
  description = "An optional identifier for this node group"
}

variable "zone_awareness" {
  type        = bool
  default     = true
  description = "Should the cluster autoscaler be aware of the AZ it is launching nodes into, if true then one ASG is created per AZ. If false a single AZ spanning all the zones will be created, applications making use of EBS volumes may not work as expected"
}

variable "root_volume_size" {
  type        = number
  default     = 40
  description = "Volume size for the root partition. Value in GiB."
}

variable "max_size" {
  type        = number
  default     = 12
  description = "The maximum number of instances that will be launched by this group, if not a multiple of the number of AZs in the group, may be rounded down"
}

variable "min_size" {
  type        = number
  default     = 0
  description = "The minimum number of instances that will be launched by this group, if not a multiple of the number of AZs in the group, may be rounded up"
}

variable "instance_size" {
  type        = string
  default     = "large"
  description = "The size of instances in this node group"
}

variable "instance_family" {
  type        = string
  default     = "general_purpose"
  description = "The family of instances that this group will launch, should be one of: memory_optimized, general_purpose, compute_optimized or burstable. Defaults to general_purpose"
}

variable "instance_lifecycle" {
  type        = string
  default     = "spot"
  description = "The lifecycle of instances managed by this group, should be 'spot' or 'on_demand'."
}

variable "spot_allocation_strategy" {
  type        = string
  default     = "lowest-price"
  description = "How to allocate capacity across the Spot pools. Valid values: 'lowest-price' or 'capacity-optimized'."
}

variable "gpu" {
  type        = bool
  default     = false
  description = "Set if using GPU instance types"
}

variable "cloud_config" {
  type        = list(string)
  default     = []
  description = "Provide additional cloud-config(s), will be merged with the default config"
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels that will be added to the kubernetes node. A qualified name must consist of alphanumeric characters, '-', '_' or '.', and must start and end with an alphanumeric character (e.g. 'MyName',  or 'my.name',  or '123-abc', regex used for validation is '([A-Za-z0-9][-A-Za-z0-9_.]*)?[A-Za-z0-9]') with an optional DNS subdomain prefix and '/' (e.g. 'example.com/MyName')"
  # TODO: add custom validation rule once the feature is stable https://www.terraform.io/docs/configuration/variables.html#custom-validation-rules
}

variable "taints" {
  type        = map(string)
  default     = {}
  description = "taints that will be added to the kubernetes node"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A map of additional tags to apply to this groups AWS resources"
}

variable "instance_types" {
  type        = list(string)
  description = <<EOF
Can be set to a custom list of instance types if one of the presets is not suitable (if set instance_size is ignored, instance_family should be used to provide a description of the instances managed by this group)
e.g. [\"i3.xlarge\", \"i3en.xlarge\"]
The CPU and Memory resources on each type should be the same, or the cluster autoscaler may not work properly.
EOF
  default     = []
}

variable "key_name" {
  type        = string
  default     = ""
  description = "SSH keypair name for the nodes"
}

variable "security_groups" {
  type        = list(string)
  default     = []
  description = "Additional security groups for the nodes"
}

variable "termination_policies" {
  type        = list(string)
  default     = ["OldestLaunchTemplate", "OldestInstance"]
  description = "A list of policies to decide how the instances in the auto scale group should be terminated."
}

variable "enabled_metrics" {
  type = list(string)
  default = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupInServiceCapacity",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingInstances",
    "GroupPendingCapacity",
    "GroupStandbyInstances",
    "GroupStandbyCapacity",
    "GroupTerminatingInstances",
    "GroupTerminatingCapacity",
    "GroupTotalInstances",
    "GroupTotalCapacity",
  ]
  description = "A list of metrics to collect."
}

variable "cluster_autoscaler" {
  type        = bool
  default     = true
  description = "Should this group be managed by the cluster autoscaler"
}

variable "bottlerocket" {
  type        = bool
  default     = false
  description = "Use Bottlerocket OS, rather than Amazon Linux"
}

variable "bottlerocket_admin_container_enabled" {
  type        = bool
  default     = false
  description = "Should the bottlerocket admin container (for ssh access) be enabled by default"
}

variable "bottlerocket_admin_container_superpowered" {
  type        = bool
  default     = true
  description = "Whether the admin container has high levels of access to the Bottlerocket host."
}

variable "bottlerocket_admin_container_source" {
  type        = string
  default     = ""
  description = "URI of a custom admin container image"
}
