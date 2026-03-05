#!/bin/bash

set -euo pipefail

export AWS_ROLE_ARN="arn:aws:iam::214219211678:role/TerraformAWSEKSTests"
source hack/assume_role.sh

cd examples/cluster/environment
terraform init
terraform apply
