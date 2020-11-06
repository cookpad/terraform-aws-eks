#!/bin/bash

export AWS_ROLE_ARN="arn:aws:iam::214219211678:role/TerraformAWSEKSTests"
source hack/assume_role.sh

cd test
go test -v -timeout 90m -run TestTerraformAwsEksCluster | grep -v "constructing many client instances from the same exec auth config"
