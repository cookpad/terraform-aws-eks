#!/bin/bash

set -euo pipefail

# If the terraform version is specified install the correct one
tfenv install || true

cd test
go test -v -timeout 60m "$@" | grep -v "constructing many client instances from the same exec auth config"
