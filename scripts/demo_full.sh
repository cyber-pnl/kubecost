#!/usr/bin/env bash
#
# Démo complète rejouable : reset -> déploiement des équipes -> simulations
# -> rapport de chargeback. Conçue pour tenir un pitch de ~10 min.
#
# Usage :
#   ./scripts/demo_full.sh                # sans reset ? non : reset par défaut
#   ./scripts/demo_full.sh --keep         # conserve l'état (pas de reset)
#   ./scripts/demo_full.sh --spike        # ajoute le pic de charge (lent ~5 min)
#   ./scripts/demo_full.sh --window 1d    # fenêtre du rapport Kubecost
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require kubectl
check_cluster

RESET=true
SPIKE=false
WINDOW="1d"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep) RESET=false ;;
    --spike) SPIKE=true ;;
    --window) WINDOW="${2:?--window requiert une valeur}"; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) err "option inconnue: $1" ;;
  esac
  shift
done

PF_PID=""
cleanup() {
  if [[ -n "${PF_PID}" ]] && kill -0 "${PF_PID}" 2>/dev/null; then
    kill "${PF_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

api_ready() {
  curl -fsS -o /dev/null "http://localhost:9090/model/allocation?window=1m" 2>/dev/null
}

start_port_forward() {
  if api_ready; then
    info "port-forward Kubecost déjà actif sur :9090"
    return 0
  fi
  info "ouverture du port-forward Kubecost (9090)"
  kubectl -n kubecost port-forward svc/kubecost-cost-analyzer 9090:9090 >/dev/null 2>&1 &
  PF_PID=$!
  for _ in $(seq 1 15); do
    sleep 1
    api_ready && return 0
  done
  err "port-forward Kubecost indisponible"
}

info "############ DÉMO KUBECOST — démarrage $(date '+%F %T') ############"

if [[ "${RESET}" == "true" ]]; then
  info "### 1/5 reset du lab"
  "${SCRIPT_DIR}/reset_scenario.sh"
else
  info "### 1/5 reset ignoré (--keep)"
fi

info "### 2/5 déploiement des 4 équipes"
"${SCRIPT_DIR}/deploy_teams.sh"

info "### 3/5 simulations des patterns de coût"
"${SCRIPT_DIR}/simulate_overprovisioning.sh"
"${SCRIPT_DIR}/simulate_orphan_resources.sh"
"${SCRIPT_DIR}/simulate_idle_waste.sh"
if [[ "${SPIKE}" == "true" ]]; then
  info "pic de charge demandé (--spike) : cela peut prendre plusieurs minutes"
  "${SCRIPT_DIR}/simulate_traffic_spike.sh"
else
  info "pic de charge ignoré (ajoutez --spike) ; le HPA se démontre via simulate_traffic_spike.sh"
fi

info "### 4/5 rapport de chargeback (fenêtre ${WINDOW})"
start_port_forward
python3 "${SCRIPT_DIR}/../chargeback/generate_report.py" --window "${WINDOW}"

info "### 5/5 terminé — rapport dans chargeback/reports/"
info "logs de la démo : ${SCRIPT_DIR}/logs/"
info "############ DÉMO KUBECOST — fin $(date '+%F %T') ############"