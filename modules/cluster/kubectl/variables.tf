variable "config" {
  type = object({
    name     = string
    ca_data  = string
    endpoint = string
  })
  description = "cluster config"
}

variable "namespace" {
  type = string
  default = "kube-system"
  description = "the kubernetes namespace to set in the kubectl context"
}

variable "manifest" {
  type        = string
  description = "the kubernetes manifest to apply"
}

variable "kubectl" {
  type        = string
  description = "The kubectl binary to use"
  default     = "kubectl"
}

variable "apply" {
  type        = bool
  description = "Do nothing if false"
  default     = true
}
