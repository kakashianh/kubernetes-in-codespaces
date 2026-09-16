#!/usr/bin/env bash

# full reset: delete cluster, rebuild, redeploy
# source code and manifests are preserved - only cluster state is lost

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_BASE="$(dirname "${SCRIPT_DIR}")"

echo "Deleting cluster..."
bash "${SCRIPT_DIR}/cluster-down.sh"

echo "Recreating cluster..."
bash "${SCRIPT_DIR}/cluster-up.sh"

echo "Bootstrapping infrastructure..."
bash "${SCRIPT_DIR}/bootstrap.sh"

echo "Deploying apps..."
if [ -f "${REPO_BASE}/cli/kic" ]; then
  cd "${REPO_BASE}" || exit 1
  kic cluster deploy 2>/dev/null || kubectl apply -f "${REPO_BASE}/deploy/apps" || true
fi

echo ""
echo "Dev environment reset complete."
echo "Run 'kic pods' or 'kubectl get pods -A' to verify."
