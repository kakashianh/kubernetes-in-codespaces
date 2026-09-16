# Unified develop environment for cloud-based Kubernetes development
# This image is a toolbox - it does NOT run databases or the cluster itself.
# The k3d cluster + local registry are created at Codespace creation time.

FROM mcr.microsoft.com/devcontainers/base:ubuntu

ARG USERNAME=vscode

# install basic tools via apt
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        wget \
        jq \
        unzip \
        zip \
        tree \
        make \
        vim \
        nano \
        netcat-openbsd \
        ca-certificates \
        gnupg \
        lsb-release \
        httpie \
    && rm -rf /var/lib/apt/lists/*

# install the pinned Kubernetes development tools
COPY scripts/install-tools.sh /tmp/install-tools.sh

RUN bash /tmp/install-tools.sh \
    && rm /tmp/install-tools.sh

USER ${USERNAME}

WORKDIR /workspaces
