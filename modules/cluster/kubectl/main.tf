locals {
  command = templatefile(
    "${path.module}/command.sh",
    {
      kubeconfig_path = "${path.module}/${sha1(var.manifest)}.kubeconfig"
      replace         = var.replace ? [1] : []
      apply           = var.replace ? [] : [1]
    }
  )
  kubeconfig = templatefile(
    "${path.module}/kubeconfig.yaml",
    {
      cluster_name = var.config.name
      ca_data      = var.config.ca_data
      endpoint     = var.config.endpoint
      token        = data.aws_eks_cluster_auth.auth.token
      namespace    = var.namespace
    }
  )
}

data "aws_eks_cluster_auth" "auth" {
  name = var.config.name
}

resource "null_resource" "apply" {
  count = var.apply ? 1 : 0

  triggers = {
    manifest_sha1 = sha1(var.manifest)
  }

  provisioner "local-exec" {
    command     = local.command
    interpreter = ["/bin/sh", "-ec"]
    environment = {
      KUBECONFIG = local.kubeconfig
      MANIFEST   = var.manifest
    }
  }
}
