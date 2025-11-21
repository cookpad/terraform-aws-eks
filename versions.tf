# Run hack/versions k8sVersionNumber > versions.tf
# to generate the latest values for this
locals {
  versions = {
    k8s                = "1.34"
    vpc_cni            = "v1.20.5-eksbuild.1"
    kube_proxy         = "v1.34.1-eksbuild.2"
    coredns            = "v1.12.4-eksbuild.1"
    aws_ebs_csi_driver = "v1.53.0-eksbuild.1"
  }
}
