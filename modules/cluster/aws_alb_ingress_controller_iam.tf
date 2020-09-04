locals {
  aws_alb_ingress_controller_iam_role_count = length(var.aws_alb_ingress_controller_iam_role_arn) == 0 && var.aws_alb_ingress_controller ? 1 : 0
  aws_alb_ingress_controller_iam_role_arn   = length(var.aws_alb_ingress_controller_iam_role_arn) > 0 ? var.aws_alb_ingress_controller_iam_role_arn : join("", aws_iam_role.aws_alb_ingress_controller.*.arn)
}

data "aws_iam_policy_document" "aws_alb_ingress_controller_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster_oidc.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:alb-ingress-controller"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.cluster_oidc.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "aws_alb_ingress_controller" {
  count                = local.aws_alb_ingress_controller_iam_role_count
  name                 = "EksALBIngressController-${var.name}"
  assume_role_policy   = data.aws_iam_policy_document.aws_alb_ingress_controller_assume_role_policy.json
  permissions_boundary = var.aws_alb_ingress_controller_iam_permissions_boundary
}

# https://github.com/kubernetes-sigs/aws-alb-ingress-controller/blob/v1.1.9/docs/examples/iam-policy.json
data "aws_iam_policy_document" "aws_alb_ingress_controller_policy" {
  statement {
    effect = "Allow"
    actions = [
      "acm:DescribeCertificate",
      "acm:ListCertificates",
      "acm:GetCertificate",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DeleteSecurityGroup",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVpcs",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:RevokeSecurityGroupIngress"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:SetWebAcl"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
      "iam:GetServerCertificate",
      "iam:ListServerCertificates",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "cognito-idp:DescribeUserPoolClient",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "waf-regional:GetWebACLForResource",
      "waf-regional:GetWebACL",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "tag:GetResources",
      "tag:TagResources",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "waf:GetWebACL",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "shield:DescribeProtection",
      "shield:GetSubscriptionState",
      "shield:DeleteProtection",
      "shield:CreateProtection",
      "shield:DescribeSubscription",
      "shield:ListProtections",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "aws_alb_ingress_controller" {
  count  = local.aws_alb_ingress_controller_iam_role_count
  name   = "aws_alb_ingress_controller"
  role   = aws_iam_role.aws_alb_ingress_controller[0].id
  policy = data.aws_iam_policy_document.aws_alb_ingress_controller_policy.json
}
