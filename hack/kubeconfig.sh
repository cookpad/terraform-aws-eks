#!/bin/bash

export AWS_ROLE_ARN="arn:aws:iam::214219211678:role/TerraformAWSEKSTests"
source hack/assume_role.sh

cd examples/cluster
aws eks update-kubeconfig --name $(terraform output cluster_name) --role-arn $AWS_ROLE_ARN --alias=terraform-aws-eks-test
