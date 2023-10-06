variable "cluster_config" {
  description = "EKS cluster config object"
  type = object({
    name = string
    arn = string
    private_subnet_ids = map(string)
    iam_role_name_prefix = string
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
