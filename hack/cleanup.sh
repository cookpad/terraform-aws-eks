#!/bin/bash

export AWS_ROLE_ARN="arn:aws:iam::214219211678:role/TerraformAWSEKSTests"
export SKIP_deploy_terraform=true
export SKIP_validate=true

.github/actions/terratest/entrypoint.sh -run "${@:-TestTerraformAwsEksCluster}"
