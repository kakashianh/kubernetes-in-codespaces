#!/bin/bash

# this runs as part of pre-build (container image build completes first)

echo "on-create start"
echo "$(date +'%Y-%m-%d %H:%M:%S')    on-create start" >> "$HOME/status"

# clone repos
git clone https://github.com/cse-labs/imdb-app /workspaces/imdb-app
git clone https://github.com/microsoft/webvalidate /workspaces/webvalidate

# restore the repos
dotnet restore /workspaces/webvalidate/src/webvalidate.sln
dotnet restore /workspaces/imdb-app/src/imdb.csproj

export REPO_BASE=$PWD
export PATH="$PATH:$REPO_BASE/cli"

mkdir -p "$HOME/.ssh"

{
    # add cli to path
    echo "export PATH=\$PATH:$REPO_BASE/cli"

    echo "export REPO_BASE=$REPO_BASE"
    echo "compinit"
} >> "$HOME/.zshrc"

echo "generating completions"
kic completion zsh > "$HOME/.oh-my-zsh/completions/_kic" 2>/dev/null || true
kubectl completion zsh > "$HOME/.oh-my-zsh/completions/_kubectl"

echo "creating k3d cluster"
bash scripts/cluster-up.sh

# bootstrap first: creates namespaces + ingress + infra (postgres/redis/monitoring/apps)
# apps applied here may fail to pull local images until 'kic build' pushes them
echo "deploying k3d cluster"
bash scripts/bootstrap.sh

echo "building IMDb"
kic build imdb

echo "building WebValidate"
sed -i "s/RUN dotnet test//g" /workspaces/webvalidate/Dockerfile
kic build webv

# only run apt upgrade on pre-build
if [ "$CODESPACE_NAME" = "null" ]
then
    sudo apt-get update
    sudo apt-get upgrade -y
    sudo apt-get autoremove -y
    sudo apt-get clean -y
fi

echo "on-create complete"
echo "$(date +'%Y-%m-%d %H:%M:%S')    on-create complete" >> "$HOME/status"
