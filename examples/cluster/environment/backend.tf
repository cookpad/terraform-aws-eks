terraform {
  backend "s3" {
    bucket = "cookpad-terraform-aws-eks-testing"
    key    = "test-environment"
    region = "us-east-1"
  }
}
