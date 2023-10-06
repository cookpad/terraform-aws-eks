provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["214219211678"]
}

provider "kubernetes" {
  host                   = module.cluster.config.endpoint
  cluster_ca_certificate = base64decode(module.cluster.config.ca_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.cluster.config.name]
  }
}

data "http" "ip" {
  url = "http://ipv4.icanhazip.com"
}

module "cluster" {
  source = "../../"

  name = var.cluster_name

  vpc_config = data.terraform_remote_state.environment.outputs.vpc_config

  endpoint_public_access       = true
  endpoint_public_access_cidrs = ["${chomp(data.http.ip.body)}/32"]


  aws_auth_role_map = [
    {
      username = aws_iam_role.test_role.name
      rolearn  = aws_iam_role.test_role.arn
      groups   = ["system:masters"]
    },
    {
      username = "system:node:{{EC2PrivateDNSName}}"
      rolearn  = module.karpenter.node_role_arn
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    },
  ]

  tags = {
    Project = "terraform-aws-eks"
  }
}

module "karpenter" {
  source = "../../modules/karpenter"

  cluster_config = module.cluster.config
  oidc_config    = module.cluster.oidc_config
}

data "aws_security_group" "nodes" {
  id = module.cluster.config.node_security_group
}
