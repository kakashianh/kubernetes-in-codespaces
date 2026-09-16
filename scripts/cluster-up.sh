#!/usr/bin/env bash

# creates the k3d cluster and local registry
# idempotent - safe to run multiple times

set -euo pipefail

# configuration
CLUSTER="dev"
REGISTRY="registry.localhost"
REGISTRY_PORT="5500"
NETWORK="k3d"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_BASE="$(dirname "${SCRIPT_DIR}")"
K3D_CONFIG="${REPO_BASE}/.devcontainer/k3d.yaml"

# profile determines the number of agent nodes
#   minimal: 1 agent,  backend: 2 agents,  full: 2 agents
DEV_PROFILE="${DEV_PROFILE:-full}"

case "${DEV_PROFILE}" in
  minimal) AGENTS=1 ;;
  backend) AGENTS=2 ;;
  full)    AGENTS=2 ;;
  *)       echo "Unknown DEV_PROFILE '${DEV_PROFILE}' - expected minimal|backend|full" >&2; exit 1 ;;
esac

echo "DEV_PROFILE=${DEV_PROFILE} (agents=${AGENTS})"
echo "REPO_BASE=${REPO_BASE}"

# 1. make sure the docker network exists (needed for registry + cluster)
if ! docker network inspect "${NETWORK}" >/dev/null 2>&1; then
  echo "Creating docker network '${NETWORK}'..."
  docker network create "${NETWORK}"
else
  echo "Docker network '${NETWORK}' already exists."
fi

# 2. make sure the local registry exists
if ! k3d registry get "${REGISTRY}" >/dev/null 2>&1; then
  echo "Creating k3d registry '${REGISTRY}' on port ${REGISTRY_PORT}..."
  k3d registry create "${REGISTRY}" --port "${REGISTRY_PORT}"
fi

# the registry container is created on the k3d network
# make sure it is also connected to the k3d docker network
if ! docker network inspect "${NETWORK}" \
  --format '{{range .Containers}}{{.Name}} {{end}}' | grep -q "${REGISTRY}"; then
  echo "Connecting registry to docker network '${NETWORK}'..."
  docker network connect "${NETWORK}" "k3d-${REGISTRY}" 2>/dev/null || true
fi

# 3. create the cluster (uses .devcontainer/k3d.yaml)
if k3d cluster get "${CLUSTER}" >/dev/null 2>&1; then
  echo "Cluster '${CLUSTER}' already exists."
else
  echo "Creating k3d cluster '${CLUSTER}' (servers=1, agents=${AGENTS})..."
  k3d cluster create "${CLUSTER}" \
    --config "${K3D_CONFIG}" \
    --agents "${AGENTS}" \
    --registry-use "k3d-${REGISTRY}:${REGISTRY_PORT}" \
    --wait
fi

# 4. wait for nodes to be ready
echo "Waiting for Kubernetes nodes..."
kubectl wait \
  --for=condition=Ready \
  nodes \
  --all \
  --timeout=180s

# 5. fix permissions on hostPath volumes so non-root images can write
#    prometheus runs as uid 65534 (nobody), grafana as uid 472
echo "Setting volume permissions on cluster nodes..."
for node in $(docker ps --format '{{.Names}}' | grep "^k3d-${CLUSTER}-" || true); do
  docker exec "${node}" sh -c 'chown 65534:65534 /prometheus 2>/dev/null || true; chown 472:472 /grafana 2>/dev/null || true' >/dev/null 2>&1 || true
done

echo "Cluster ready."
kubectl get nodes
