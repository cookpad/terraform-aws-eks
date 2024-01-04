terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.49.0"
    }

    assert = {
      source  = "bwoznicki/assert"
      version = "0.0.1"
    }
  }
}
