locals {
  kubeconfig = templatefile(
    "${path.module}/kubeconfig.tmpl",
    {
      cluster_name = var.config.name
      ca_data      = var.config.ca_data
      endpoint     = var.config.endpoint
      token        = data.aws_eks_cluster_auth.auth.token
    }
  )
  kubeconfig_path = "${path.module}/${sha1(local.kubeconfig)}.${sha1(var.manifest)}.kubeconfig"
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
    command = <<EOT
cat <<EOF > ${local.kubeconfig_path}
${local.kubeconfig}
EOF

${var.kubectl} --kubeconfig=${local.kubeconfig_path} apply -f -<<EOF
${var.manifest}
EOF

rm ${local.kubeconfig_path}
EOT
  }
}
