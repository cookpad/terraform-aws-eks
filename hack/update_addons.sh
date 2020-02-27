#!/bin/bash

set -xeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"


helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm repo add eks https://aws.github.io/eks-charts

helm repo update

helm_template() {
  helm template --no-hooks --namespace=kube-system --version $3 -f helm/$2.yaml $2 $1/$2 | grep -v Helm > ../modules/cluster/addons/$2.yaml
}

helm_template eks aws-node-termination-handler 0.5.1
helm_template stable cluster-autoscaler 6.6.1
helm_template stable metrics-server 2.10.0
helm_template stable prometheus-node-exporter 1.9.0
