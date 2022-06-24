#!/bin/bash

set -xeuo pipefail
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
ADDONS_DIR=../modules/cluster/addons

helm repo add eks https://aws.github.io/eks-charts
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm_template() {
  helm template --no-hooks --namespace=kube-system --version $3 -f $ADDONS_DIR/helm/$2.yaml $2 $1/$2${4:-} | grep -v Helm > $ADDONS_DIR/$2.yaml
}

kustomize_build() {
  kustomize build $ADDONS_DIR/kustomize/overlays/$1 > $ADDONS_DIR/$1.yaml
}

helm_template autoscaler cluster-autoscaler 9.18.1
helm_template nvdp nvidia-device-plugin 0.11.0
