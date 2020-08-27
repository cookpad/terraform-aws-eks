#!/bin/bash

set -xeuo pipefail
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

ADDONS_DIR=../modules/cluster/addons

helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm repo add eks https://aws.github.io/eks-charts
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm repo update

helm_template() {
  helm template --no-hooks --namespace=kube-system --version $3 -f $ADDONS_DIR/helm/$2.yaml $2 $1/$2${4:-} | grep -v Helm > $ADDONS_DIR/$2.yaml
}

helm_template eks aws-node-termination-handler 0.7.3
helm_template stable metrics-server 2.11.1
helm_template autoscaler cluster-autoscaler 1.0.1 -chart
helm_template nvdp nvidia-device-plugin 0.6.0
