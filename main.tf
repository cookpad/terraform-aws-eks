/*
  EKS control plane
*/

resource "aws_eks_cluster" "control_plane" {
  name     = var.name
  role_arn = local.eks_cluster_role_arn
  tags     = var.tags

  version = local.versions.k8s

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

locals {
  aws_auth_configmap_data = {
    mapRoles = yamlencode(concat(
      [
        {
          rolearn  = aws_iam_role.fargate.arn
          username = "system:node:{{SessionName}}"
          groups = [
            "system:bootstrappers",
            "system:nodes",
            "system:node-proxier",
          ]
        },
      ],
      var.aws_auth_role_map,
    ))
    mapUsers = yamlencode(var.aws_auth_user_map)
  }
}

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = local.aws_auth_configmap_data

  lifecycle {
    # We are ignoring the data here since we will manage it with the resource below
    # This is only intended to be used in scenarios where the configmap does not exist
    ignore_changes = [data, metadata[0].labels, metadata[0].annotations]
  }
}

resource "kubernetes_config_map_v1_data" "aws_auth" {
  force = true

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = local.aws_auth_configmap_data

  depends_on = [
    # Required for instances where the configmap does not exist yet to avoid race condition
    kubernetes_config_map.aws_auth,
  ]
}

locals {
  create_key  = length(var.kms_cmk_arn) == 0
  kms_cmk_arn = local.create_key ? aws_kms_key.cmk.*.arn[0] : var.kms_cmk_arn
}


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
