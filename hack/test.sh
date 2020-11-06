#!/bin/bash

export AWS_ROLE_ARN="arn:aws:iam::214219211678:role/TerraformAWSEKSTests"
source hack/assume_role.sh

export SKIP_cleanup_terraform=true

cd test
go test -v -timeout 45m -run TestTerraformAwsEksCluster
