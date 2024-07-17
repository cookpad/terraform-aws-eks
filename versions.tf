# Run hack/versions k8sVersionNumber > versions.tf
# to generate the latest values for this
locals {
  versions = {
    k8s                = "1.28"
    vpc_cni            = "v1.18.2-eksbuild.1"
    kube_proxy         = "v1.28.8-eksbuild.5"
    coredns            = "v1.10.1-eksbuild.11"
    aws_ebs_csi_driver = "v1.32.0-eksbuild.1"
  }
}
