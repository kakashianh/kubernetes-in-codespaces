#!/usr/bin/env bash

# installs the Kubernetes development tools
# this script is run as part of the Docker build (as root)
# versions are pinned for reproducibility

set -euo pipefail

ARCH="$(dpkg --print-architecture)"

# pinned tool versions
KUBECTL_VERSION="v1.28.3"
HELM_VERSION="v3.14.0"
K3D_VERSION="v4.4.8"
YQ_VERSION="v4.47.1"
K9S_VERSION="v0.50.9"

echo "ARCH=$ARCH"

echo "Installing kubectl ($KUBECTL_VERSION)..."

curl -fsSL \
  "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
  -o /usr/local/bin/kubectl

chmod +x /usr/local/bin/kubectl

echo "Installing Helm ($HELM_VERSION)..."

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
  -o /tmp/get-helm-3

chmod +x /tmp/get-helm-3

DESIRED_VERSION="${HELM_VERSION}" /tmp/get-helm-3

rm /tmp/get-helm-3

echo "Installing k3d ($K3D_VERSION)..."

curl -fsSL \
  "https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-linux-${ARCH}" \
  -o /usr/local/bin/k3d

chmod +x /usr/local/bin/k3d

echo "Installing yq ($YQ_VERSION)..."

curl -fsSL \
  "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}" \
  -o /usr/local/bin/yq

chmod +x /usr/local/bin/yq

echo "Installing k9s ($K9S_VERSION)..."

curl -fsSL \
  "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${ARCH}.tar.gz" \
  -o /tmp/k9s.tar.gz

tar -xzf /tmp/k9s.tar.gz -C /tmp

mv /tmp/k9s /usr/local/bin/k9s

chmod +x /usr/local/bin/k9s

# jq is installed via apt in the Dockerfile but we ensure it exists here too
if ! command -v jq >/dev/null 2>&1; then
  echo "Installing jq..."
  apt-get update
  apt-get install -y --no-install-recommends jq
  rm -rf /var/lib/apt/lists/*
fi

echo "All tools installed. Versions:"
echo "---"
kubectl version --client
helm version --short
k3d version
yq --version
k9s version
jq --version
echo "Done."