# Run hack/versions k8sVersionNumber > versions.tf
# to generate the latest values for this
locals {
  versions = {
    k8s                = "1.30"
    vpc_cni            = "v1.18.2-eksbuild.1"
    kube_proxy         = "v1.30.0-eksbuild.3"
    coredns            = "v1.11.1-eksbuild.9"
    aws_ebs_csi_driver = "v1.32.0-eksbuild.1"
  }
}
