#!/bin/bash

set -xeuo pipefail
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
ADDONS_DIR=../modules/cluster/addons

helm repo add eks https://aws.github.io/eks-charts
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm repo update

helm_template() {
  helm template --no-hooks --namespace=kube-system --version $3 -f $ADDONS_DIR/helm/$2.yaml $2 $1/$2${4:-} | grep -v Helm > $ADDONS_DIR/$2.yaml
}

kustomize_build() {
  kustomize build $ADDONS_DIR/kustomize/overlays/$1 > $ADDONS_DIR/$1.yaml
}

helm_template eks aws-node-termination-handler 0.9.5
helm_template autoscaler cluster-autoscaler 1.0.1 -chart
helm_template nvdp nvidia-device-plugin 0.6.0

curl -o $ADDONS_DIR/kustomize/overlays/metrics-server/resources/metrics-server.yaml -L https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.7/components.yaml
kustomize_build metrics-server
curl -o $ADDONS_DIR/kustomize/overlays/aws-ebs-csi-driver/resources/crd_snapshotter.yaml -L https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/v0.6.0/deploy/kubernetes/cluster/crd_snapshotter.yaml
kustomize_build aws-ebs-csi-driver
kustomize_build aws-alb-ingress-controller
