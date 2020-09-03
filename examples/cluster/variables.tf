variable "cluster_name" {
  type    = string
  default = "test-cluster"
}

variable "aws_ebs_csi_driver" {
  type    = bool
  default = false
}
