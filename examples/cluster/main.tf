provider "aws" {
  region  = "us-east-1"
  version = "~> 2.47"
}

module "eks" {
  source = "../../."

  cluster_name       = var.cluster_name
  cidr_block         = var.cidr_block
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  # So we can access the k8s API from CI/dev
  endpoint_public_access = true
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
      - "eks"
      - "get-token"
      - "--cluster-name"
      - "$${cluster_name}"
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
