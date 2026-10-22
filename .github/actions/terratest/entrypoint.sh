#!/bin/bash

set -euo pipefail

# If the terraform version is specified install the correct one
tfenv install || true

# Authenticate to public ECR to avoid anonymous pull rate limits (token API only exists in us-east-1)
aws ecr-public get-login-password --region us-east-1 | helm registry login --username AWS --password-stdin public.ecr.aws

cd test
go test -v -timeout 90m "$@" | grep -v "constructing many client instances from the same exec auth config"
