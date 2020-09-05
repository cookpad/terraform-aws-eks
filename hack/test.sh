#!/bin/bash

set -euo pipefail

export AWS_ROLE_ARN="arn:aws:iam::214219211678:role/TerraformAWSEKSTests"
export SKIP_cleanup_terraform=true

source .github/actions/terratest/assume_role.sh

cd test
go test -v -timeout 60m -run TestTerraformAwsEksCluster | grep -v "constructing many client instances from the same exec auth config"
