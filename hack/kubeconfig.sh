#!/bin/bash

export AWS_ROLE_ARN="arn:aws:iam::214219211678:role/TerraformAWSEKSTests"
unset  AWS_SESSION_TOKEN
temp_role=$(aws sts assume-role \
                    --role-arn "$AWS_ROLE_ARN" \
                    --role-session-name "terraform-aws-eks-tests")

export AWS_ACCESS_KEY_ID=$(echo $temp_role | jq -r .Credentials.AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo $temp_role | jq -r .Credentials.SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo $temp_role | jq -r .Credentials.SessionToken)

cd examples/cluster
aws eks update-kubeconfig --name $(terraform output cluster_name) --role-arn $AWS_ROLE_ARN

