#!/usr/bin/env bash
#
# Déploie les 4 équipes du lab (namespaces puis workloads).
# `kubectl apply -R -f teams/` trie les fichiers par chemin : les
# `deployment.yaml` sont appliqués avant leur `namespace.yaml` et échouent.
# On fait donc deux passes explicites. Idempotent.
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require kubectl
check_cluster

TEAMS_DIR="${SCRIPT_DIR}/../teams"
TEAMS=(team-checkout team-catalog team-search team-platform)

info "==> Passe 1/2 : namespaces + quotas"
for ns in "${TEAMS[@]}"; do
  kubectl apply -f "${TEAMS_DIR}/${ns}/namespace.yaml" >/dev/null
done

info "==> Passe 2/2 : workloads (deployments, svc, hpa, pvc, lb, jobs)"
kubectl apply -R -f "${TEAMS_DIR}" >/dev/null

info "==> Attente de disponibilité des Deployments"
for ns in "${TEAMS[@]}"; do
  kubectl wait --for=condition=available deployment --all -n "${ns}" --timeout=120s >/dev/null 2>&1 \
    || info "avertissement : tous les deployments ne sont pas disponibles dans ${ns}"
done

log "==> État des workloads :"
kubectl get pods -A 2>/dev/null | grep team- || true
info "==> Déploiement terminé"