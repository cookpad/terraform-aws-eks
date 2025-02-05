# Run hack/versions k8sVersionNumber > versions.tf
# to generate the latest values for this
locals {
  versions = {
    k8s                = "1.32"
    vpc_cni            = "v1.19.2-eksbuild.1"
    kube_proxy         = "v1.32.0-eksbuild.2"
    coredns            = "v1.11.4-eksbuild.2"
    aws_ebs_csi_driver = "v1.39.0-eksbuild.1"
  }
}
