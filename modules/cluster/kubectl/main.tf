data "aws_caller_identity" "current" {}

locals {
  caller_role_info = regexall("arn:aws:sts::(?P<account>\\d+):assumed-role/(?P<role>\\w+)/\\d+", data.aws_caller_identity.current.arn)
  caller_role_arn  = length(local.caller_role_info) > 0 ? "arn:aws:iam::${local.caller_role_info[0]["account"]}:role/${local.caller_role_info[0]["role"]}" : ""
  role_arn         = var.role_arn != "" ? var.role_arn : local.caller_role_arn
}

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
      role_arn     = local.role_arn
      namespace    = var.namespace
    }
  )
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
