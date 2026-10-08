#!/usr/bin/env bash
#
# Reset complet du lab : supprime les 4 namespaces d'équipe (et donc les
# PVC, LoadBalancers, Jobs, HPAs créés dedans). Idempotent et rejouable.
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require kubectl
check_cluster

TEAMS=(team-checkout team-catalog team-search team-platform)

info "==> Reset du lab : suppression des namespaces d'équipe"
for ns in "${TEAMS[@]}"; do
  if kubectl get namespace "${ns}" >/dev/null 2>&1; then
    log "suppression namespace ${ns}"
    kubectl delete namespace "${ns}" --wait=true --timeout=120s >/dev/null
  else
    info "namespace ${ns} absent, rien à faire"
  fi
done

info "==> Reset terminé. Le cluster reste prêt :"
kubectl get nodes >>"${LOG_FILE}" 2>&1
info "LOG=${LOG_FILE}"