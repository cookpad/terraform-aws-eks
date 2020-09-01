/*
  EKS control plane
*/

data "aws_iam_role" "service_role" {
  name = var.iam_config.service_role
}

resource "aws_eks_cluster" "control_plane" {
  name     = var.name
  role_arn = data.aws_iam_role.service_role.arn
  tags     = var.tags

  version = var.k8s_version

  enabled_cluster_log_types = var.cluster_log_types

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    security_group_ids      = aws_security_group.control_plane.*.id
    subnet_ids              = concat(values(var.vpc_config.public_subnet_ids), values(var.vpc_config.private_subnet_ids))
  }

  dynamic "encryption_config" {
    for_each = local.encryption_configs
    content {
      resources = ["secrets"]

      provider {
        key_arn = encryption_config.value
      }
    }
  }

  depends_on = [aws_cloudwatch_log_group.control_plane]

  provisioner "local-exec" {
    # wait for api to be avalible for use before continuing
    command     = "until curl --output /dev/null --insecure --silent ${self.endpoint}/healthz; do sleep 1; done"
    working_dir = path.module
  }
}

resource "aws_iam_openid_connect_provider" "cluster_oidc" {
  url             = aws_eks_cluster.control_plane.identity.0.oidc.0.issuer
  thumbprint_list = var.oidc_root_ca_thumbprints
  client_id_list  = ["sts.amazonaws.com"]
}

resource "aws_cloudwatch_log_group" "control_plane" {
  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = 7
  tags              = var.tags
}

/*
  Allow nodes to join the cluster
*/

data "aws_iam_role" "node_role" {
  name = var.iam_config.node_role
}

locals {
  aws_auth_role_map = concat(
    [
      {
        rolearn  = data.aws_iam_role.node_role.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      },
    ],
    var.aws_auth_role_map,
  )
}

module "aws_auth" {
  source = "./kubectl"
  config = local.config
  manifest = templatefile(
    "${path.module}/aws-auth-cm.yaml.tmpl",
    {
      role_map = jsonencode(local.aws_auth_role_map)
      user_map = jsonencode(var.aws_auth_user_map)
    }
  )
}

module "storage_classes" {
  source  = "./kubectl"
  config  = local.config
  replace = true
  manifest = templatefile(
    "${path.module}/storage_classes.yaml.tmpl",
    {
      provisioner = var.aws_ebs_csi_driver ? "ebs.csi.aws.com" : "kubernetes.io/aws-ebs",
      fstype      = var.aws_ebs_csi_driver ? "csi.storage.k8s.io/fstype: ${var.pv_fstype}" : "fsType: ${var.pv_fstype}"
    }
  )
}

locals {
  create_key         = length(var.kms_cmk_arn) == 0 && var.envelope_encryption_enabled
  kms_cmk_arn        = local.create_key ? aws_kms_key.cmk.*.arn : [var.kms_cmk_arn]
  encryption_configs = var.envelope_encryption_enabled ? local.kms_cmk_arn : []
}

resource "aws_kms_key" "cmk" {
  count       = local.create_key ? 1 : 0
  description = "eks secrets cmk: ${var.name}"
}
