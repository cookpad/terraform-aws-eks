#!/bin/bash

set -xeuo pipefail
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

ADDONS_DIR=../modules/cluster/addons

helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm repo update

helm_template() {
  helm template --no-hooks --namespace=kube-system --version $3 -f $ADDONS_DIR/helm/$2.yaml $2 $1/$2 | grep -v Helm > $ADDONS_DIR/$2.yaml
}

helm_template stable cluster-autoscaler 6.6.1
