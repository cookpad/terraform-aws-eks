# In the test we provision the network and IAM resources using the environment
# module, we then lookup the relevant config here!
# This is in order to simulate launching a cluster in an existing VPC!

data "terraform_remote_state" "environment" {
  backend = "s3"

  config = {
    bucket = "cookpad-terraform-aws-eks-testing"
    key    = "test-environment"
    region = "us-east-1"
  }
}
