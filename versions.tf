# Run hack/versions k8sVersionNumber > versions.tf
# to generate the latest values for this
locals {
  versions = {
    k8s                = "1.29"
    vpc_cni            = "v1.18.5-eksbuild.1"
    kube_proxy         = "v1.29.7-eksbuild.9"
    coredns            = "v1.11.3-eksbuild.1"
    aws_ebs_csi_driver = "v1.35.0-eksbuild.1"
  }
}
