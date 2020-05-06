#!/bin/sh -l

# If the terraform version is specified install the correct one
tfenv install || true

source /assume_role.sh

cd test
go test -v -timeout 45m "$@"
