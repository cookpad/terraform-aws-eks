provider "aws" {
  region              = "us-east-1"
  version             = "3.5.0"
  allowed_account_ids = ["214219211678"]
}

module "gpu_nodes" {
  source = "../../../modules/asg_node_group"

  cluster_config = data.terraform_remote_state.cluster.outputs.cluster_config

  name     = "gpu-nodes"
  key_name = "development"

  gpu             = true
  instance_family = "gpu"
  instance_size   = "2xlarge"
  instance_types  = ["p3.2xlarge"]
  zone_awareness  = false
  min_size        = 1

  labels = {
    "k8s.amazonaws.com/accelerator" = "nvidia-tesla-v100"
  }

  taints = {
    "nvidia.com/gpu" = "gpu:NoSchedule"
  }
}
