provider "aws" {
  region  = "us-east-1"
  version = "2.49.0"
}


module "eks" {
  source = "../../."

  cluster_name       = var.cluster_name
  cidr_block         = var.cidr_block
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  # So we can access the k8s API from CI/dev
  endpoint_public_access = true

  node_labels = {
    "cookpad.com/terraform-aws-eks-test-environment" = var.cluster_name
  }

  node_taints = {
    "terraform-aws-eks" = "test:PreferNoSchedule"
  }

  aws_auth_role_map = [
    {
      username = aws_iam_role.test_role.name
      rolearn  = aws_iam_role.test_role.arn
      groups   = ["system:masters"]
    }
  ]
}

/*
  Template a kubeconfig, for testing etc.
*/
data "template_file" "kubeconfig" {
  template = <<YAML
apiVersion: v1
kind: Config
clusters:
- name: $${cluster_name}
  cluster:
    certificate-authority-data: $${ca_data}
    server: $${endpoint}
users:
- name: $${cluster_name}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws
      args:
      - --region
      - us-east-1
      - eks
      - get-token
      - --cluster-name
      - $${cluster_name}
contexts:
- name: $${cluster_name}
  context:
    cluster: $${cluster_name}
    user: $${cluster_name}
current-context: $${cluster_name}
YAML


  vars = {
    cluster_name = module.eks.cluster_config.name
    ca_data      = module.eks.cluster_config.ca_data
    endpoint     = module.eks.cluster_config.endpoint
  }
}

/*
  Template a kubeconfig to test role mappings
*/

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "test_role" {
  name_prefix        = "TerraformAWSEKS"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": "${data.aws_caller_identity.current.arn}"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "template_file" "test_role_kubeconfig" {
  template = <<YAML
apiVersion: v1
kind: Config
clusters:
- name: $${cluster_name}
  cluster:
    certificate-authority-data: $${ca_data}
    server: $${endpoint}
users:
- name: $${cluster_name}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      args:
      - --region
      - us-east-1
      - eks
      - get-token
      - --cluster-name
      - $${cluster_name}
      - --role-arn
      - $${role_arn}
      command: aws
contexts:
- name: $${cluster_name}
  context:
    cluster: $${cluster_name}
    user: $${cluster_name}
current-context: $${cluster_name}
YAML


  vars = {
    cluster_name = module.eks.cluster_config.name
    ca_data      = module.eks.cluster_config.ca_data
    endpoint     = module.eks.cluster_config.endpoint
    role_arn     = aws_iam_role.test_role.arn
  }
}
