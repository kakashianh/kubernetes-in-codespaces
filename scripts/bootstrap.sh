#!/usr/bin/env bash

# bootstraps the infrastructure + apps based on the DEV_PROFILE
#   minimal: namespaces + ingress
#   backend: minimal + postgres + redis
#   full:    backend + monitoring (prometheus/grafana) + logging (fluentbit) + apps (imdb/webv/heartbeat)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_BASE="$(dirname "${SCRIPT_DIR}")"
BOOTSTRAP="${REPO_BASE}/deploy/bootstrap"
APPS="${REPO_BASE}/deploy/apps"

DEV_PROFILE="${DEV_PROFILE:-full}"

echo "DEV_PROFILE=${DEV_PROFILE}"
echo "REPO_BASE=${REPO_BASE}"

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "Kubernetes cluster is not reachable. Run 'bash scripts/cluster-up.sh' first." >&2
  exit 1
fi

# --- minimal (all profiles) ---
kubectl apply -f "${BOOTSTRAP}/namespaces.yaml"
kubectl apply -f "${REPO_BASE}/deploy/ingress.yaml"

# --- backend ---
if [ "${DEV_PROFILE}" = "backend" ] || [ "${DEV_PROFILE}" = "full" ]; then
  kubectl apply -f "${REPO_BASE}/deploy/postgres.yaml"
  kubectl apply -f "${REPO_BASE}/deploy/redis.yaml"
fi

# --- full ---
if [ "${DEV_PROFILE}" = "full" ]; then
  # monitoring
  kubectl apply -f "${BOOTSTRAP}/prometheus"
  kubectl apply -f "${BOOTSTRAP}/grafana"
  kubectl apply -f "${BOOTSTRAP}/grafana/dashboards"

  # logging
  kubectl apply -f "${BOOTSTRAP}/fluentbit"

  # heartbeat + webv-heartbeat
  kubectl apply -f "${BOOTSTRAP}/heartbeat"
  kubectl apply -f "${BOOTSTRAP}/webv-heartbeat"

  # apps (imdb + webv)
  kubectl apply -f "${APPS}"
fi

echo ""
echo "Bootstrap complete (profile: ${DEV_PROFILE})."
kubectl get pods -A 2>/dev/null || true
