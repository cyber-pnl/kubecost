#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${1:-kubecost-lab}"

log() { printf '\033[1;34m[teardown]\033[0m %s\n' "$*"; }

command -v k3d >/dev/null 2>&1 || { echo "[teardown][ERROR] k3d requis — introuvable dans le PATH" >&2; exit 1; }

if k3d cluster list 2>/dev/null | awk '{print $1}' | grep -qx "${CLUSTER_NAME}"; then
    log "Suppression du cluster '${CLUSTER_NAME}'..."
    k3d cluster delete "${CLUSTER_NAME}"
    log "OK — cluster '${CLUSTER_NAME}' supprimé."
else
    log "Cluster '${CLUSTER_NAME}' absent — rien à faire."
fi