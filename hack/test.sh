#!/bin/bash

export SKIP_cleanup_terraform="${SKIP_cleanup_terraform:-true}"
export AWS_ROLE_ARN="arn:aws:iam::214219211678:role/TerraformAWSEKSTests"

.github/actions/terratest/entrypoint.sh -run "${@:-TestTerraformAwsEksCluster}"
