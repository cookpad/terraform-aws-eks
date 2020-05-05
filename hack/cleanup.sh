#!/bin/bash

export AWS_ROLE_ARN="arn:aws:iam::214219211678:role/TerraformAWSEKSTests"
source .github/actions/terratest/assume_role.sh

clean() {
  terraform destroy -refresh=false -auto-approve
  rm -rf .test-data
  rm -rf .terraform
  rm terraform.tfstate*
}

cd examples/cluster
clean
cd environment
clean
