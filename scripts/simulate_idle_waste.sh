#!/usr/bin/env bash
#
# Simule le pattern IDLE WASTE : ressources réservées 24/7 sans charge.
# Réutilise team-checkout (requests 1 CPU/2Gi, usage ~0) - le coût reste
# constant dans Kubecost malgré une absence totale d'activité.
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require kubectl
check_cluster

info "==> Idle waste : team-checkout (requests 1 CPU/2Gi), usage quasi nul"
kubectl apply -R -f "${REPO_ROOT}/teams/team-checkout/" >/dev/null
kubectl -n team-checkout rollout status deploy/checkout-api --timeout=90s >/dev/null

info "==> CPU constaté (flat-line attendu, requests inchangées) :"
kubectl top pod -n team-checkout >>"${LOG_FILE}" 2>&1 \
  || warn "métriques non disponibles (metrics-server en cours ?)"
info "==> Coût alloué constant = coût du gaspillage (voir Kubecost)."
info "LOG=${LOG_FILE}"