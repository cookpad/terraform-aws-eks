# Run hack/versions to generate the latest values for this
locals {
  versions = {
    k8s                = "1.25"
    vpc_cni            = "v1.12.6-eksbuild.2"
    kube_proxy         = "v1.25.9-eksbuild.1"
    coredns            = "v1.9.3-eksbuild.3"
    aws_ebs_csi_driver = "v1.19.0-eksbuild.2"
  }
}
