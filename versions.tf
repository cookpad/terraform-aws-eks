# Run hack/versions k8sVersionNumber > versions.tf
# to generate the latest values for this
locals {
  versions = {
    k8s                = "1.35"
    vpc_cni            = "v1.23.3-eksbuild.1"
    kube_proxy         = "v1.35.3-eksbuild.69"
    coredns            = "v1.14.7-eksbuild.35"
    aws_ebs_csi_driver = "v1.68.0-eksbuild.1"
  }
}
