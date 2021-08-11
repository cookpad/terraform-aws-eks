terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.53.0"
    }
  }
}

provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["214219211678"]
}

module "gpu_nodes" {
  source = "../../../modules/asg_node_group"

  cluster_config = data.terraform_remote_state.cluster.outputs.cluster_config

  name     = "gpu-nodes"
  key_name = "development"

  gpu                = true
  instance_family    = "gpu"
  instance_size      = "xlarge"
  instance_types     = ["g4dn.xlarge"]
  zone_awareness     = false
  min_size           = 1
  instance_lifecycle = "on_demand"

  labels = {
    "k8s.amazonaws.com/accelerator" = "nvidia-tesla-v100"
  }

  taints = {
    "nvidia.com/gpu" = "gpu:NoSchedule"
  }
}
