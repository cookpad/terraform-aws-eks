# Run hack/versions k8sVersionNumber > versions.tf
# to generate the latest values for this
locals {
  versions = {
    k8s                = "1.36"
    vpc_cni            = "v1.23.2-eksbuild.3"
    kube_proxy         = "v1.36.0-eksbuild.48"
    coredns            = "v1.14.7-eksbuild.11"
    aws_ebs_csi_driver = "v1.67.1-eksbuild.1"
  }
}
