# Run hack/versions k8sVersionNumber > versions.tf
# to generate the latest values for this
locals {
  versions = {
    k8s                = "1.32"
    vpc_cni            = "v1.20.5-eksbuild.1"
    kube_proxy         = "v1.32.11-eksbuild.5"
    coredns            = "v1.11.4-eksbuild.28"
    aws_ebs_csi_driver = "v1.56.0-eksbuild.1"
  }
}
