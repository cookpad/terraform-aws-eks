/*
  EKS control plane
*/

data "aws_iam_role" "service_role" {
  name = var.iam_config.service_role
}
locals {
  k8s_version = "1.19"
}

resource "aws_eks_cluster" "control_plane" {
  name     = var.name
  role_arn = data.aws_iam_role.service_role.arn
  tags     = var.tags

  version = local.k8s_version

  enabled_cluster_log_types = var.cluster_log_types

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access_cidrs
    security_group_ids      = concat(aws_security_group.control_plane.*.id, var.security_group_ids)
    subnet_ids              = concat(values(var.vpc_config.public_subnet_ids), values(var.vpc_config.private_subnet_ids))
  }

  encryption_config {
    resources = ["secrets"]

    provider {
      key_arn = local.kms_cmk_arn
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
  kms_key_id        = local.kms_cmk_arn
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
  create_key  = length(var.kms_cmk_arn) == 0
  kms_cmk_arn = local.create_key ? aws_kms_key.cmk.*.arn[0] : var.kms_cmk_arn
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_iam_policy_document" "cloudwatch" {
  policy_id = "key-policy-cloudwatch"
  statement {
    sid = "Enable IAM User Permissions"
    actions = [
      "kms:*",
    ]
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        format(
          "arn:%s:iam::%s:root",
          data.aws_partition.current.partition,
          data.aws_caller_identity.current.account_id
        )
      ]
    }
    resources = ["*"]
  }
  statement {
    sid = "AllowCloudWatchLogs"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        format(
          "logs.%s.amazonaws.com",
          data.aws_region.current.name
        )
      ]
    }
    resources = ["*"]
    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        format(
          "arn:aws:logs:%s:%s:log-group:/aws/eks/%s/cluster",
          data.aws_region.current.name,
          data.aws_caller_identity.current.account_id,
          var.name,
        )
      ]
    }
  }
}


resource "aws_kms_key" "cmk" {
  count               = local.create_key ? 1 : 0
  description         = "eks secrets cmk: ${var.name}"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.cloudwatch.json
}
