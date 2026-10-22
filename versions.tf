# Run hack/versions k8sVersionNumber > versions.tf
# to generate the latest values for this
locals {
  versions = {
    k8s                = "1.37"
    vpc_cni            = "v1.23.2-eksbuild.3"
    kube_proxy         = "v1.37.0-eksbuild.22"
    coredns            = "v1.14.7-eksbuild.11"
    aws_ebs_csi_driver = "v1.67.1-eksbuild.1"
  }
}
