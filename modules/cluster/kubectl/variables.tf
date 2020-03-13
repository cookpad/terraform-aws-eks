variable "config" {
  type = object({
    name           = string
    admin_role_arn = string
  })
  description = "cluster config"
}

variable "namespace" {
  type        = string
  default     = "kube-system"
  description = "the kubernetes namespace to set"
}

variable "manifest" {
  type        = string
  description = "the kubernetes manifest to apply"
}

variable "apply" {
  type        = bool
  description = "Do nothing if false"
  default     = true
}
