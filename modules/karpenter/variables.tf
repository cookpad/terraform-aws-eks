variable "cluster_config" {
  description = "EKS cluster config object"
  type = object({
    name                       = string
    arn                        = string
    private_subnet_ids         = map(string)
    iam_role_name_prefix       = string
    fargate_execution_role_arn = string
  })
}

variable "oidc_config" {
  description = "OIDC config object"
  type = object({
    url = string
    arn = string
  })
}

variable "additional_node_role_arns" {
  description = <<-EOF
    Additional Node Role ARNS that karpenter should manage

    This can be used where karpenter is using existing node
    roles, and you want to transition to the namespaced role
    created by this module
  EOF
  type        = list(string)
  default     = []
}
