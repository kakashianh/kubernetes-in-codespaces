# Kubernetes-in-Codespaces Makefile
# development wrapper for the k3d cluster + apps
#
# usage:
#   make up        - create the cluster (idempotent)
#   make down      - delete the cluster (keeps registry)
#   make restart   - down + up
#   make reset     - full cluster reset + deploy
#   make status    - pods + services
#   make logs      - tail logs for the api app
#   make db        - open a psql shell in postgres
#   make redis     - open a redis-cli shell
#   make deploy    - apply all manifests
#   make build     - build + deploy local imdb/webv images (kic)
#   make check     - validate endpoints (kic)
#   make k9s       - open k9s
#   make profile   - show current DEV_PROFILE

CLUSTER = dev
PROFILE ?= $(shell echo "$${DEV_PROFILE:-full}")

.PHONY: help up down restart reset status logs deploy build check k9s profile db redis

help: ## show this help
	@echo "Usage: make [target]"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'
	@echo ""
	@echo "Dev targets (no description):"
	@echo "  up / down / restart / reset / status / deploy / build / check / logs / db / redis / k9s / profile"

up:
	@bash scripts/cluster-up.sh

down:
	@bash scripts/cluster-down.sh

restart:
	$(MAKE) down
	$(MAKE) up

reset:
	@bash scripts/dev-reset.sh

status:
	@kubectl get pods -A
	@echo ""
	@kubectl get svc -A

logs:
	@kubectl logs -n imdb -l app=imdb --tail=100 -f

deploy:
	@bash scripts/bootstrap.sh

build:
	@cd "$(shell git rev-parse --show-toplevel 2>/dev/null || echo .)" && kic build imdb && kic build webv

check:
	@echo "==> imdb (imdb.localhost:8080)"
	@curl -sS -o /dev/null -w "  /version          : %{http_code}\n" -H 'Host: imdb.localhost' localhost:8080/version
	@curl -sS -o /dev/null -w "  /readyz           : %{http_code}\n" -H 'Host: imdb.localhost' localhost:8080/readyz
	@echo "==> heartbeat (heartbeat.localhost:8080)"
	@curl -sS -o /dev/null -w "  /heartbeat/17     : %{http_code}\n" -H 'Host: heartbeat.localhost' localhost:8080/heartbeat/17
	@echo "==> grafana (grafana.localhost:8080)"
	@curl -sS -o /dev/null -w "  /login            : %{http_code}\n" -H 'Host: grafana.localhost' localhost:8080/login
	@echo "==> prometheus (prometheus.localhost:8080)"
	@curl -sS -o /dev/null -w "  /-/ready          : %{http_code}\n" -H 'Host: prometheus.localhost' localhost:8080/-/ready

k9s:
	@k9s

profile:
	@echo "DEV_PROFILE=$(PROFILE)"

db:
	@kubectl exec -it -n dev statefulset/postgres -- psql -U dev -d app

redis:
	@kubectl exec -it -n dev deployment/redis -- redis-cli
