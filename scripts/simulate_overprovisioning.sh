#!/usr/bin/env bash
#
# Simule le pattern OVER-PROVISIONING : requêtes très hautes pour un usage
# minime (team-checkout). Effet attendu dans Kubecost : écart alloué vs
# utilisé -> candidat n°1 au rightsizing.
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require kubectl
check_cluster

info "==> team-checkout : requests 1 CPU / 2Gi pour ~0.1 CPU d'usage"
kubectl apply -R -f "${REPO_ROOT}/teams/team-checkout/" >/dev/null
kubectl -n team-checkout rollout status deploy/checkout-api --timeout=90s >/dev/null

info "==> Usage réel (devrait être ~0, requests étant 1 CPU / 2Gi) :"
kubectl top pod -n team-checkout >>"${LOG_FILE}" 2>&1 \
  || warn "métriques non disponibles (metrics-server en cours ?)"

info "==> Terminé. Corréler avec Kubecost : allocation?aggregate=label:team"
info "LOG=${LOG_FILE}"