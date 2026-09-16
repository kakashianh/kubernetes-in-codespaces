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

echo "post-start complete"
echo "$(date +'%Y-%m-%d %H:%M:%S')    post-start complete" >> "$HOME/status"