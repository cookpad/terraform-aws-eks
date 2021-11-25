terraform {
  required_version = ">= 0.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.49"
    }

    assert = {
      source  = "bwoznicki/assert"
      version = "0.0.1"
    }
  }
}
