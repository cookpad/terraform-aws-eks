terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.71, < 4.0.0" # 1st version where instance_metadata_tags var exists.
    }

    assert = {
      source  = "bwoznicki/assert"
      version = "0.0.1"
    }
  }
}
