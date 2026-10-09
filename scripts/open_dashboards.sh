#!/usr/bin/env bash
#
# Ouvre les port-forwards des dashboards (Kubecost + Grafana) pour la démo ou
# la capture de screenshots. Reste actif jusqu'à Ctrl-C.
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require kubectl
check_cluster

KUBECOST_PORT="${KUBECOST_PORT:-9090}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"
PIDS=()

cleanup() {
  for pid in "${PIDS[@]:-}"; do
    kill "${pid}" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

open_svc() {
  local ns="$1" svc="$2" mapping="$3"
  if kubectl -n "${ns}" get svc "${svc}" >/dev/null 2>&1; then
    kubectl -n "${ns}" port-forward "svc/${svc}" "${mapping}" >/dev/null 2>&1 &
    PIDS+=("$!")
    info "port-forward ${ns}/${svc} -> ${mapping}"
  else
    info "service ${ns}/${svc} absent (ignoré)"
  fi
}

open_svc kubecost kubecost-cost-analyzer "${KUBECOST_PORT}:9090"
open_svc kubecost grafana "${GRAFANA_PORT}:80"
sleep 2

echo
echo "Interfaces disponibles :"
echo "  Kubecost : http://localhost:${KUBECOST_PORT}"
echo "  Grafana  : http://localhost:${GRAFANA_PORT}  (admin / mot de passe dans le secret 'grafana')"
[[ -n "${KUBECOST_PORT}" ]] && echo "  Rapport  : chargeback/reports/chargeback-*.html"
echo
echo "Ctrl-C pour fermer. Captures : voir docs/screenshots/README.md"
wait
