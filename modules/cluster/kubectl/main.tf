data "aws_region" "current" {}

locals {
  command = templatefile(
    "${path.module}/command.sh",
    {
      region       = data.aws_region.current.name
      cluster_name = var.config.name
      kubeconfig   = "${path.module}/${sha1(var.manifest)}.kubeconfig"
      role_arn     = var.config.admin_role_arn
      manifest     = var.manifest
      namespace    = var.namespace
    }
  )
}

resource "null_resource" "apply" {
  count = var.apply ? 1 : 0

  triggers = {
    manifest_sha1 = sha1(local.command)
  }

  provisioner "local-exec" {
    command     = local.command
    interpreter = ["/bin/sh", "-ec"]
  }
}
