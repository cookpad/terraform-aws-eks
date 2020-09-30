# In the test we provision the network and IAM resources using the environment
# module, we then lookup the relevant config here!
# This is in order to simulate launching a cluster in an existing VPC!

data "terraform_remote_state" "environment" {
  backend = "local"

  config = {
    path = "${path.module}/environment/terraform.tfstate"
  }
}
