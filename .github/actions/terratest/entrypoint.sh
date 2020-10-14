#!/bin/bash

set -euo pipefail

# If the terraform version is specified install the correct one
tfenv install || true

source /assume_role.sh

cd test
go test -v -timeout 90m "$@" | grep -v "constructing many client instances from the same exec auth config"
