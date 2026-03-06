# Run hack/versions k8sVersionNumber > versions.tf
# to generate the latest values for this
locals {
  versions = {
    k8s                = "1.33"
    vpc_cni            = "v1.21.1-eksbuild.3"
    kube_proxy         = "v1.33.8-eksbuild.4"
    coredns            = "v1.13.2-eksbuild.1"
    aws_ebs_csi_driver = "v1.56.0-eksbuild.1"
  }
}
