#!/bin/sh -l

# If the terraform version is specified install the correct one
tfenv install || true

cd test
go test -v -timeout 45m "$@"
