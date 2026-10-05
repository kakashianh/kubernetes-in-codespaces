#!/bin/bash

# this runs each time the container starts

echo "post-start start"
echo "$(date +'%Y-%m-%d %H:%M:%S')    post-start start" >> "$HOME/status"

# make sure the k3d cluster is running (idempotent)
if [ -x "$(command -v k3d)" ] && ! k3d cluster get dev >/dev/null 2>&1; then
  echo "k3d cluster 'dev' not found - recreating"
  bash scripts/cluster-up.sh || true
fi

# update the base docker images
docker pull mcr.microsoft.com/dotnet/aspnet:6.0-alpine || true
docker pull mcr.microsoft.com/dotnet/sdk:6.0 || true
docker pull ghcr.io/cse-labs/webv-red:latest || true

# keep the Forwarded Ports open across restarts (idempotent; kill stale first)
# note: must bind 0.0.0.0 or Codespaces returns 502/refused behind the forwarded URL
if kubectl get svc prometheus-service -n monitoring >/dev/null 2>&1 && kubectl get svc webv -n imdb >/dev/null 2>&1; then
  # entries: "localPort svc/name namespace servicePort"
  port_forward_entries=(
    "9090 svc/prometheus-service monitoring 8080"
    "3001 svc/grafana monitoring 3000"
    "8082 svc/imdb imdb 8080"
    "8083 svc/webv imdb 8080"
    "8084 svc/heartbeat heartbeat 8080"
    "8085 svc/webv-heartbeat heartbeat 8080"
  )
  for forward in "${port_forward_entries[@]}"; do
    read -r local service namespace sp <<<"$forward"
    name="$(basename "$service")"
    pkill -f "port-forward.*$service.*$local" 2>/dev/null || true
    nohup kubectl port-forward --address 0.0.0.0 -n "$namespace" "$service" "$local:$sp" >"/tmp/pf-$name.log" 2>&1 &
  done
fi

echo "post-start complete"
echo "$(date +'%Y-%m-%d %H:%M:%S')    post-start complete" >> "$HOME/status"