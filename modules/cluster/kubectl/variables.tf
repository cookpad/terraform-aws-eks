variable "config" {
  type = object({
    name     = string
    ca_data  = string
    endpoint = string
  })
  description = "cluster config"
}

variable "manifests" {
  type        = map(string)
  description = "the kubernetes manifests to apply"
  default     = {}
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
