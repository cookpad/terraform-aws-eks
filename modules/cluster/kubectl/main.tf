locals {
  manifest = replace(var.manifest, "$", "\\$")
  command = templatefile(
    "${path.module}/command.sh",
    {
      cluster_name = var.config.name
      ca_data      = var.config.ca_data
      endpoint     = var.config.endpoint
      token        = data.aws_eks_cluster_auth.auth.token
      kubeconfig   = "${path.module}/${sha1(var.manifest)}.kubeconfig"
      manifest     = local.manifest
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
    manifest_sha1 = sha1(local.manifest)
  }

  provisioner "local-exec" {
    command     = local.command
    interpreter = ["/bin/sh", "-ec"]
  }
}
