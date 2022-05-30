terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }

    assert = {
      source  = "bwoznicki/assert"
      version = "0.0.1"
    }
  }
}
