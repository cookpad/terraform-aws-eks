#!/bin/bash

set -xeuo pipefail
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
ADDONS_DIR=../modules/cluster/addons

helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update

helm_template() {
  helm template --no-hooks --namespace=kube-system --version $3 -f $ADDONS_DIR/helm/$2.yaml $2 $1/$2${4:-} | grep -v Helm > $ADDONS_DIR/$2.yaml
}

helm_template autoscaler cluster-autoscaler 9.19.3
