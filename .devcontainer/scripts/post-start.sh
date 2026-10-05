#!/bin/bash

# This runs each time the container starts.
# IMPORTANT:
# - Never block Codespace startup.
# - Never use pkill.
# - Port-forward runs in background.
# - Kubernetes failures must not stop the container.

echo "post-start start"
echo "$(date +'%Y-%m-%d %H:%M:%S')    post-start start" >> "$HOME/status"

# --------------------------------------------------
# 1. Make sure k3d cluster exists
# --------------------------------------------------

if command -v k3d >/dev/null 2>&1; then

  if ! timeout 10s k3d cluster get dev >/dev/null 2>&1; then
    echo "k3d cluster 'dev' not found - recreating"

    if [ -f "scripts/cluster-up.sh" ]; then
      timeout 120s bash scripts/cluster-up.sh || \
        echo "WARNING: cluster-up.sh failed or timed out"
    else
      echo "WARNING: scripts/cluster-up.sh not found"
    fi
  else
    echo "k3d cluster 'dev' already exists"
  fi

fi

# --------------------------------------------------
# 2. Docker images
# --------------------------------------------------
# Do not block Codespace startup for too long.

if command -v docker >/dev/null 2>&1; then

  echo "Updating Docker images..."

  timeout 60s docker pull \
    mcr.microsoft.com/dotnet/aspnet:6.0-alpine \
    || echo "WARNING: failed to pull aspnet image"

  timeout 60s docker pull \
    mcr.microsoft.com/dotnet/sdk:6.0 \
    || echo "WARNING: failed to pull dotnet sdk image"

  timeout 60s docker pull \
    ghcr.io/cse-labs/webv-red:latest \
    || echo "WARNING: failed to pull webv image"

fi

# --------------------------------------------------
# 3. Kubernetes port forwarding
# --------------------------------------------------
#
# IMPORTANT:
# - Do NOT use pkill here.
# - Do NOT make all services depend on each other.
# - Missing services are simply skipped.
# - Each port-forward runs independently.
#

if command -v kubectl >/dev/null 2>&1; then

  port_forward_entries=(
    "9090 svc/prometheus-service monitoring 8080"
    "3001 svc/grafana monitoring 3000"
    "8082 svc/imdb imdb 8080"
    "8083 svc/webv imdb 8080"
    "8084 svc/heartbeat heartbeat 8080"
    "8085 svc/webv-heartbeat heartbeat 8080"
  )

  for forward in "${port_forward_entries[@]}"; do

    read -r local service namespace sp <<< "$forward"

    # Check service individually.
    if ! timeout 5s kubectl get "$service" -n "$namespace" >/dev/null 2>&1; then
      echo "Skipping $service - service not available"
      continue
    fi

    name="$(basename "$service")"

    echo "Starting port-forward:"
    echo "  $service"
    echo "  namespace: $namespace"
    echo "  localhost:$local -> $sp"

    # Start in background.
    #
    # No pkill.
    # No wait.
    # No blocking.
    nohup kubectl port-forward \
      --address 0.0.0.0 \
      -n "$namespace" \
      "$service" \
      "$local:$sp" \
      >"/tmp/pf-$name.log" 2>&1 &

    echo $! > "/tmp/pf-$name.pid"

  done

fi

# --------------------------------------------------
# 4. Finish immediately
# --------------------------------------------------

echo "post-start complete"
echo "$(date +'%Y-%m-%d %H:%M:%S')    post-start complete" >> "$HOME/status"

exit 0
