#!/bin/bash

unset  AWS_SESSION_TOKEN
temp_role=$(aws sts assume-role \
                    --role-arn "$AWS_ROLE_ARN" \
                    --role-session-name "terraform-aws-eks-tests")

export AWS_ACCESS_KEY_ID=$(echo $temp_role | jq -r .Credentials.AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo $temp_role | jq -r .Credentials.SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo $temp_role | jq -r .Credentials.SessionToken)
