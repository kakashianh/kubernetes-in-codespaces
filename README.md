# Kubernetes in Codespaces

> Setup a Kubernetes cluster using `k3d` running in [GitHub Codespaces](https://github.com/features/codespaces)

![License](https://img.shields.io/badge/license-MIT-green.svg)

## Overview

This is a template that will setup a Kubernetes developer cluster using `k3d` in a `GitHub Codespace`.

We use this for `inner-loop` Kubernetes development. Note that it is not appropriate for production use but is a great `Developer Experience`. Feedback calls the approach `game-changing` - we hope you agree!

For ideas, feature requests, and discussions, please use GitHub discussions so we can collaborate and follow up.

This Codespace is tested with `zsh` and `oh-my-zsh`.

You can connect to the Codespace with a local version of VS Code.

Please experiment and add any issues to the GitHub Discussion.

## Stack

The development environment is fully self-contained and reproducible:

- **k3d cluster** (`dev`) with `k3s v1.28.3` - the k3s version is pinned to stay in sync with the kubectl client and to get a Traefik version that supports the `IngressClassName` API
- **Local container registry** (`registry.localhost:5500`) - load images into the cluster with `kic build`
- **Traefik Ingress** - all apps are exposed via host-based routing on `*.localhost:8080` (no NodePorts)
- **PostgreSQL 17** - StatefulSet with a 10Gi PVC (`dev` namespace)
- **Redis 7** - Deployment with `maxmemory 128mb allkeys-lru` (`dev` namespace)
- **Prometheus + Grafana** with two pre-provisioned dashboards (IMDb, Dotnet)
- **Fluent Bit** (stdout) for logs
- **hazy/fluentd-style "webv" workloads** (`imdb` + `heartbeat` namespaces) that generate load so you can see live metrics

### Profiles

The bootstrap is profile-driven. `DEV_PROFILE` selects how much of the stack gets installed:

| Profile | Agents | Namespaces + Ingress | PostgreSQL + Redis | Monitoring + Logging + Apps |
|---------|:------:|:--------------------:|:------------------:|:---------------------------:|
| `minimal` | 1 | ✅ | | |
| `backend` | 2 | ✅ | ✅ | |
| `full` | 2 | ✅ | ✅ | ✅ |

- The agent count (size of the cluster: 1 vs 2 server agents) is chosen in `.devcontainer/k3d.yaml` when the cluster is created.
- The bootstrap (`scripts/bootstrap.sh`) is **additive**: it only ever applies manifests for the selected profile and never deletes resources. Running it again is always safe.
- Default profile is `full`.

Set the profile by changing `DEV_PROFILE` in `.devcontainer/devcontainer.json` (or pass it inline when running `bash scripts/bootstrap.sh`).

## Checking the k3d Cluster

- A k3d cluster is created as part of the Codespace setup
  - `kic` is a small CLI that we use to simplify Kubernetes development

  ```bash

  # check the pods
  kic pods

  ```

- Output from `kic pods` should resemble this

  ```text

  NAMESPACE     NAME                                      READY   STATUS              RESTARTS   AGE
  kube-system   local-path-provisioner-5ff76fc89d-wfpjx   1/1     Running             0          48s
  kube-system   coredns-7448499f4d-dnjzl                  1/1     Running             0          48s
  kube-system   metrics-server-86cbb8457f-qlp8v           1/1     Running             0          48s
  logging       fluentbit-cq45s                           1/1     Running             0          32s
  kube-system   helm-install-traefik-crd-zk5gr            0/1     Completed           0          48s
  kube-system   helm-install-traefik-mbr2l                0/1     Completed           1          48s
  heartbeat     heartbeat-65978f8f88-dw9fn                1/1     Running             0          32s
  default       jumpbox                                   1/1     Running             0          32s
  imdb          imdb-79d8c756b-2p465                      1/1     Running             0          33s
  monitoring    grafana-5df456f89c-2r6cm                  1/1     Running             0          32s
  kube-system   svclb-traefik-2ks5t                       2/2     Running             0          22s
  kube-system   traefik-97b44b794-txs9h                   1/1     Running             0          22s
  heartbeat     webv-heartbeat-776cbf6fbf-jvk5x           1/1     Running             0          32s
  imdb          webv-796c76d69d-5ghnq                     1/1     Running             0          4s
  monitoring    prometheus-deployment-5c57d9b77d-tdtn2    1/1     Running             0          32s

  ```

![Running Codespace](./images/RunningCodespace.png)

## Validate Deployment

- If you get an error, just run the command again - it will clear once the services are ready

```bash

# check all endpoints (via the Traefik Ingress) - returns 0 only if everything is healthy
make check

# check the pods + services
make status

```

### Validating endpoints

All apps are reachable through the **Traefik Ingress** on port `8080` using `Host`-based routing:

| Host | App | Notes |
|------|-----|-------|
| `imdb.localhost` | IMDb-app | Swagger + movie API |
| `heartbeat.localhost` | Heartbeat | logs every 5s |
| `grafana.localhost` | Grafana | `admin` / `cse-labs` |
| `prometheus.localhost` | Prometheus | UI |

```bash

# e.g. curl the imdb service through the ingress
curl -i -H 'Host: imdb.localhost' localhost:8080/version

```

The routing rules live in [`deploy/ingress.yaml`](./deploy/ingress.yaml).

Open [curl.http](./curl.http)

> [curl.http](./curl.http) is used in conjuction with the Visual Studio Code [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client) extension.
>
> When you open [curl.http](./curl.http), you should see a clickable `Send Request` text above each of the URLs

![REST Client example](./images/RESTClient.png)

Clicking on `Send Request` should open a new panel in Visual Studio Code with the response from that request like so:

![REST Client example response](./images/RESTClientResponse.png)

> **Codespaces note:** port forwarding in the Codespaces browser forwards to `*.app.github.dev`, not `localhost`, so `Host`-based routing works best from the terminal (curl/httpie). If you need to open an app in the browser widget, the label of each forwarded port is still configured in `.devcontainer/devcontainer.json` (`8080` Ingress, `5432` Postgres, `6379` Redis, `9090`, ...).

## Data Services

PostgreSQL and Redis run in the `dev` namespace and are exposed on the cluster's load balancer so the host can reach them on regular ports:

```bash

# PostgreSQL - host reachable on localhost:5432
PGPASSWORD=dev psql -h localhost -p 5432 -U dev -d app -c 'select version();'

# Redis - host reachable on localhost:6379
redis-cli -h localhost -p 6379 ping   # => PONG

```

| Service | Namespace | Host port | Credentials |
|---------|:---------:|-----------|-------------|
| `postgres` (StatefulSet) | `dev` | 5432 | `dev` / `dev` / db `app` |
| `redis` (Deployment) | `dev` | 6379 | — |

## Persistence Strategy

Three tiers of persistence, chosen by what makes sense for a dev environment:

1. **Node volumes** (`hostPath`, survive pod restarts but not `make reset` unless re-created):
   - Prometheus data, Grafana data - mounted on the nodes (`/prometheus`, `/grafana`) and `chown`-ed via init containers + `cluster-up.sh` so pods on any node can write.
2. **Kubernetes PVC** (survives cluster rebuilds because k3d mounts the volumes into the container):
   - PostgreSQL 10Gi PVC (`volumeClaimTemplates` in the StatefulSet).
3. **Ephemeral** - everything else:
   - Redis (in-memory, `maxmemory 128mb allkeys-lru` - fine for dev).
   - Local registry images.

## Jump Box

A `jump box` pod is created so that you can execute commands `in the cluster`

- use the `kj` alias
  - example
    - run `kj`
      - Your terminal prompt will change
      - From the `jumpbox` terminal
      - Run `http imdb.imdb.svc.cluster.local:8080/version`
      - `exit` back to the Codespaces terminal

- use the `kje` alias
  - example
    - run http against the ClusterIP
      - `kje http imdb.imdb.svc.cluster.local:8080/version`

- Since the jumpbox is running `in` the cluster, we use the service name and port, not the NodePort
  - A jumpbox is great for debugging network issues

## Ports & Forwarding

- Codespaces exposes `ports` to the local browser
- The cluster exposes everything through the **Traefik Ingress on `8080`**, and Postgres/Redis via the service `LoadBalancer` ports
- Codespaces ports are setup in the `.devcontainer/devcontainer.json` file

  ```json

  // forward ports for the app (Ingress + data services)
  "forwardPorts": [
    8080,
    5432,
    6379,
    9090,
    3001
  ],

  ```

  ```json

  // add labels
  "portsAttributes": {
    "8080": { "label": "Traefik Ingress" },
    "5432": { "label": "PostgreSQL" },
    "6379": { "label": "Redis" },
    "9090": { "label": "Prometheus" },
    "3001": { "label": "Grafana" }
  },

  ```

> NodePorts are no longer used - see the ingress section below.

## View IMDB App

- Open the ingress port (`8080`) with the `Host` header set:
  - `curl http://imdb.localhost:8080/` from a terminal, or
  - `curl -i -H 'Host: imdb.localhost' localhost:8080/`
- This will show the imdb-app home page (Swagger)

## View Heartbeat

- `curl http://heartbeat.localhost:8080/heartbeat/17`
  - Or with a Host header: `curl -i -H 'Host: heartbeat.localhost' localhost:8080/heartbeat/17`
- Heartbeat does not have a UI - the page says `Under construction ...` but the JSON endpoint works.

## Build and deploy a local version of imdb-app

- We have a local Docker container registry running in the Codespace
  - Run `docker ps` to see the running images
- Build the WebAPI app from the local source code
- Push to the local Docker registry
- Deploy to local k3d cluster

- Switch back to your Codespaces tab

  ```bash

  # from Codespaces terminal

  # make and deploy a local version of imdb-app to k8s
  kic build imdb

  # check the app version
  # the semver will have the current date and time
  curl -i -H 'Host: imdb.localhost' localhost:8080/version

  ```

## Validate deployment with k9s

> To exit K9s - `:q <enter>`

- From the Codespace terminal window, start `k9s`
  - Type `k9s` and press enter
  - Press `0` to select all namespaces

  - Use the arrow key to select `webv` pod for `heartbeat` then press the `l` key to view logs from the pod
    - Notice that WebV is making a heartbeat request every 5 seconds
    - To go back, press the `esc` key

  - Use the arrow key to select `webv` pod for `imdb` then press the `l` key to view logs from the pod
    - Notice that WebV is making 10 IMDb requests per second
    - To go back, press the `esc` key

  - Use the arrow key to select `jumpbox` then press `s` key to open a shell in the container
    - Test the `IMDb-App` service from within the cluster by executing

      ```bash

      # httpie is a "pretty" version of curl
      # test the webv-imdb service endpoint using local DNS
      http webv.imdb.svc.cluster.local:8080/metrics

      ```

      - `exit <enter>`
  - To view other resources - press `shift + :` followed by the deployment type (e.g. `secret`, `services`, `deployment`, etc).

![k9s](./images/k9s.png)

## View Fluent Bit Logs

> Fluent Bit is set to forward logs to stdout for debugging
>
> Fluent Bit can be configured to forward to different services including Grafana Cloud or Azure Log Analytics
>
> Fluent Bit is also installed in the Codespace to simplify debugging new configurations. Run `fluent-bit --help` for more details.

- Start `k9s` from the Codespace terminal (if it's not running from previous step)
- Press `0` to show all `namespaces`
- Select `fluentbit` pod and press `enter`
- Press `enter` again to see the logs
- Press `s` to Toggle AutoScroll
- Press `w` to Toggle Wrap
- Review logs that will be sent to Grafana when configured

> To exit K9s - `:q <enter>`

## View Prometheus Dashboard

- `curl -i -H 'Host: prometheus.localhost' localhost:8080/-/ready`
- Or open the browser: `http://prometheus.localhost:8080`

- From the Prometheus tab
  - Begin typing `ImdbAppDuration_bucket` in the `Expression` search
  - Click `Execute`
  - This will display the log table that Grafana uses for the charts

## View Grafana Dashboard

- Grafana login info
  - admin
  - cse-labs

- `curl -i -H 'Host: grafana.localhost' localhost:8080/login`
- Or open the browser: `http://grafana.localhost:8080`

![Codespace Ports](./images/CodespacePorts.jpg)

> `IMDb-App` dashboard is set as the default home dashboard to visualize constant load generated to the IMDB application.

![Grafana](./images/imdb-requests-by-mode.png)

### Explore Grafana Dashboards

- Click on the dashboard folder `General` at the top (with four squares) to access the dashboard search. The dashboard search can also be opened by using the shortcut `F`.
- The list will show all the dashboards configured in Grafana.
- We configure two dashboards as part of the initial deployment:
  - IMDb App
  - Dotnet

## Run integration and load tests

```bash

# from Codespaces terminal

# run an integration test (will generate warnings in Grafana)
kic test integration

# run a 30 second load test
kic test load

```

- Switch to the Grafana browser tab
- The integration test generates 400 and 404 results by design
- The requests metric will go from green to yellow to red as load increases
  - It may skip yellow
- As the test completes
  - The metric will go back to green (10 req/sec)
  - The request graph will return to normal

![Load Test](./images/test-with-errors-and-load-test.png)

## How Codespaces is built

Codespaces extends the use of development containers by providing a remote hosting environment. A development container is a fully-featured development environment running in a Docker container.

Developers can simply click on a button in GitHub to open a Codespace for the repo. Behind the scenes, GitHub Codespaces is:

- Starting a VM
- Shallow clone the repo in that VM. The shallow clone pulls the `devcontainer.json` onto the VM
- Start the development container on the VM
- Clone the repository in the development container
- Connect to the remotely hosted development container via the browser or Visual Studio Code

### Repository layout

```text

.
├── .devcontainer/                 # devcontainer definition + lifecycle scripts
│   ├── Dockerfile
│   ├── devcontainer.json
│   ├── k3d.yaml                   # cluster config (agents, ports, k3s image pin)
│   └── scripts/
│       ├── install-tools.sh       # pinned tool versions (kubectl, helm, k3d, ...)
│       ├── on-create.sh           # runs once when the container is created
│       ├── post-start.sh          # runs every time the container starts
│       └── ...
├── scripts/
│   ├── cluster-up.sh              # create the k3d cluster (idempotent)
│   ├── cluster-down.sh
│   ├── bootstrap.sh               # profile-driven manifest bootstrap (additive)
│   └── dev-reset.sh               # cluster down + up + bootstrap
├── deploy/
│   ├── ingress.yaml               # Traefik host routing (imdb/heartbeat/grafana/prometheus.localhost)
│   ├── postgres.yaml              # PostgreSQL StatefulSet + LoadBalancer service
│   ├── redis.yaml                 # Redis Deployment + LoadBalancer service
│   ├── apps/                      # imdb, webv lab apps
│   └── bootstrap/                 # prometheus, grafana, fluentbit, heartbeat, webv-heartbeat, namespaces
├── cli/
│   ├── kic                        # the kic CLI (compiled)
│   └── .kic/commands/             # bash sub-commands (build, check, ...)
├── curl.http                      # REST Client requests
├── Makefile                       # make up / down / status / check / logs / ...
└── context/de-xuat-hoan-thien/    # hoàn-thiện proposal + plan (Tiếng Việt)

```

`.devcontainer` folder contains the following:

- `devcontainer.json`: This configuration file determines the environment for new Codespaces created for the repository by defining a development container that can include frameworks, tools, extensions, and port forwarding. For more information about the settings and properties that you can set in a devcontainer.json, see [devcontainer.json reference](https://code.visualstudio.com/docs/remote/devcontainerjson-reference) in the Visual Studio Code documentation.

- `Dockerfile`: Dockerfile in `.devcontainer` defines a container image and installs software. You can use an existing base image by using the `FROM` instruction. For more information on using a Dockerfile in a dev container, see [Create a development container](https://code.visualstudio.com/docs/remote/create-dev-container#_dockerfile) in the Visual Studio Code documentation.

- `scripts/`: We keep the lifecycle scripts under `.devcontainer/scripts`. They are the hooks that allow you to run commands at different points in the development container lifecycle which include:
  - onCreateCommand - Run when creating the container
  - postCreateCommand - Run after the container is created
  - postStartCommand - Run every time the container starts

  For more information on using Lifecycle scripts, see [Codespaces lifecycle scripts](https://code.visualstudio.com/docs/remote/devcontainerjson-reference#_lifecycle-scripts).

  > Note: Provide executable permissions to scripts using: `chmod +x`.

## Makefile

A `Makefile` wraps the common workflows:

```bash

make up        # create cluster (idempotent)
make down      # delete cluster
make reset     # cluster down + up + bootstrap (full reset)
make status    # kic pods + kic svc
make check     # verify all endpoints via ingress (curl + Host header)
make logs      # follow imdb + heartbeat logs
make db        # PGPASSWORD=dev psql -h localhost -p 5432 -U dev -d app
make redis     # redis-cli -h localhost -p 6379
make k9s       # open k9s
make help      # list all targets

```

## Next Steps

> Explore your Kubernetes in Codespaces cluster

- kic CLI
- K9s
- kubectl
- Docker
- helm

If you break your cluster, just rebuild it using

```bash

make reset

# or manually:
# bash scripts/cluster-down.sh && bash scripts/cluster-up.sh && bash scripts/bootstrap.sh

```

## FAQ

- Why don't we use helm to deploy Kubernetes manifests?
  - The target audience for this repository is app developers so we chose simplicity for the Developer Experience.
  - In our daily work, we use Helm for deployments and it is installed in the `Codespace` should you want to use it.
- Why `k3d` instead of `Kind`?
  - We love kind! Most of our code will run unchanged in kind (except the cluster commands)
  - We had to choose one or the other as we don't have the resources to validate both
  - We chose k3d for these main reasons
    - Smaller memory footprint
    - Faster startup time
    - Secure by default
      - K3s supports the [CIS Kubernetes Benchmark](https://rancher.com/docs/k3s/latest/en/security/hardening_guide/)
    - Based on [K3s](https://rancher.com/docs/k3s/latest/en/) which is a certified Kubernetes distro
      - Many customers run K3s on the edge as well as in CI-CD pipelines
    - Rancher provides support - including 24x7 (for a fee)
    - K3s has a vibrant community
    - K3s is a CNCF sandbox project
- Why does `k3d.yaml` pin `rancher/k3s:v1.28.3-k3s1`?
  - k3d v4.4.8's default image is k3s v1.21.3 (2021), whose bundled Traefik (2.4.x) does not support `spec.ingressClassName` - which made every Ingress return 404. Pinning k3s v1.28.3 keeps the server version aligned with the kubectl client and fixes Ingress.
- Why Ingress + `*.localhost` instead of NodePorts?
  - One gateway port (`8080`) instead of many random high ports (30000-32000). Host-based routing (`imdb.localhost`, `grafana.localhost`, ...) is closer to how production exposes services.
- Why is the registry name still `registry.localhost:5500`?
  - The `kic build` scripts reference the registry by that name (`k3d-registry.localhost:5500`); renaming it would break image loads into the cluster.

### Engineering Docs

- Team Working [Agreement](.github/WorkingAgreement.md)
- Team [Engineering Practices](.github/EngineeringPractices.md)
- CSE Engineering Fundamentals [Playbook](https://github.com/Microsoft/code-with-engineering-playbook)

## How to file issues and get help

This project uses GitHub Issues to track bugs and feature requests. Please search the existing issues before filing new issues to avoid duplicates. For new issues, file your bug or feature request as a new issue.

For help and questions about using this project, please open a GitHub issue.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us the rights to use your contribution. For details, visit <https://cla.opensource.microsoft.com>

When you submit a pull request, a CLA bot will automatically determine whether you need to provide a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services.

Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).

Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.

Any use of third-party trademarks or logos are subject to those third-party's policies.
