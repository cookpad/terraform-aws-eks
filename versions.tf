# Run hack/versions k8sVersionNumber > versions.tf
# to generate the latest values for this
locals {
  versions = {
    k8s                = "1.25"
    vpc_cni            = "v1.16.2-eksbuild.1"
    kube_proxy         = "v1.25.9-eksbuild.1"
    coredns            = "v1.9.3-eksbuild.9"
    aws_ebs_csi_driver = "v1.27.0-eksbuild.1"
  }
}
