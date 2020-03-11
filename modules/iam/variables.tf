variable "service_role_name" {
  type    = string
  default = "eksServiceRole"
}

variable "node_role_name" {
  type    = string
  default = "EKSNode"
}

variable "admin_role_name" {
  type    = string
  default = "EKSAdmin"
}
