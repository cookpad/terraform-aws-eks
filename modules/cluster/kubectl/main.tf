data "aws_region" "current" {}

data "template_file" "command" {
  template = length(var.command_template) > 0 ? var.command_template : file("${path.module}/command.sh")
  vars = {
    region       = data.aws_region.current.name
    cluster_name = var.config.name
    kubeconfig   = "${path.module}/${sha1(var.manifest)}.kubeconfig"
    role_arn     = var.config.admin_role_arn
    manifest     = var.manifest
    namespace    = var.namespace
  }
}

resource "null_resource" "apply" {
  count = var.apply ? 1 : 0

  triggers = {
    manifest_sha1 = sha1(data.template_file.command.rendered)
  }

  provisioner "local-exec" {
    command = data.template_file.command.rendered
  }
}
