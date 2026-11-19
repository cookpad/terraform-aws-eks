# Run hack/versions k8sVersionNumber > versions.tf
# to generate the latest values for this
locals {
  versions = {
    k8s                = "1.34"
    vpc_cni            = "v1.23.3-eksbuild.1"
    kube_proxy         = "v1.34.6-eksbuild.69"
    coredns            = "v1.13.2-eksbuild.75"
    aws_ebs_csi_driver = "v1.68.0-eksbuild.1"
  }
}
