#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${SCRIPT_DIR}/k3d-config.yaml"
CLUSTER_NAME="kubecost-lab"

log() { printf '\033[1;34m[setup]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[setup][ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

# --- Préconditions -----------------------------------------------------------
command -v k3d >/dev/null 2>&1 || fail "k3d requis (https://k3d.io) — introuvable dans le PATH"
command -v kubectl >/dev/null 2>&1 || fail "kubectl requis — introuvable dans le PATH"
[ -f "$CONFIG" ] || fail "config introuvable : ${CONFIG}"

# --- Provisionning (idempotent) ----------------------------------------------
if k3d cluster list 2>/dev/null | awk '{print $1}' | grep -qx "${CLUSTER_NAME}"; then
    log "Cluster '${CLUSTER_NAME}' déjà présent — réutilisation (supprimer pour recréer)."
    k3d kubeconfig merge "${CLUSTER_NAME}" >/dev/null 2>&1 || true
else
    log "Création du cluster '${CLUSTER_NAME}' depuis ${CONFIG} ..."
    k3d cluster create --config "$CONFIG"
fi

# --- Vérifications -------------------------------------------------------------
log "Attente des nodes Ready (timeout 180s)..."
kubectl wait --for=condition=Ready node --all --timeout=180s

log "Vérification metrics-server (attente jusqu'à 180s)..."
end=$((SECONDS + 180))
until kubectl top nodes >/dev/null 2>&1; do
    if (( SECONDS >= end )); then
        fail "metrics API indisponible après 180s — vérifier kube-system/metrics-server"
    fi
    log "metrics API pas encore prête — nouvelle tentative dans 5s..."
    sleep 5
done
kubectl top nodes

log "Récapitulatif :"
kubectl cluster-info
kubectl get nodes -o wide

log "OK — cluster '${CLUSTER_NAME}' prêt pour la Phase 2 (Kubecost)."