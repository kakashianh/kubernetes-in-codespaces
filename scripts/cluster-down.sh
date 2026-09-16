#!/usr/bin/env bash

# deletes the k3d cluster but keeps the local registry
# safe to run multiple times

set -euo pipefail

CLUSTER="dev"
REGISTRY="registry.localhost"

if k3d cluster get "${CLUSTER}" >/dev/null 2>&1; then
  echo "Deleting k3d cluster '${CLUSTER}'..."
  k3d cluster delete "${CLUSTER}"
else
  echo "Cluster '${CLUSTER}' does not exist."
fi

if k3d registry get "${REGISTRY}" >/dev/null 2>&1; then
  echo "Keeping local registry '${REGISTRY}' (images preserved)."
else
  echo "Registry '${REGISTRY}' does not exist."
fi

echo "Done."
