# Run hack/versions k8sVersionNumber > versions.tf
# to generate the latest values for this
locals {
  versions = {
    k8s                = "1.26"
    vpc_cni            = "v1.18.2-eksbuild.1"
    kube_proxy         = "v1.26.9-eksbuild.2"
    coredns            = "v1.9.3-eksbuild.9"
    aws_ebs_csi_driver = "v1.32.0-eksbuild.1"
  }
}
