#!/usr/bin/env bash
#
# Helpers communs aux scripts de simulation.
# À sourcer en tête de script : source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
#
set -euo pipefail

# Emplacement de common.sh (scripts/), en suivant les éventuels symlinks.
_COMMON_SOURCE="${BASH_SOURCE[0]}"
while [ -L "${_COMMON_SOURCE}" ]; do
  _COMMON_SOURCE="$(readlink "${_COMMON_SOURCE}")"
done
SCRIPTS_DIR="$(cd "$(dirname "${_COMMON_SOURCE}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPTS_DIR}/.." && pwd)"
LOGS_DIR="${SCRIPTS_DIR}/logs"
mkdir -p "${LOGS_DIR}"

# Nom du script appelant (common.sh exclu) -> prefixe du log.
_SCRIPT_NAME="$(basename "${BASH_SOURCE[1]:-$0}" .sh)"
LOG_FILE="${LOGS_DIR}/${_SCRIPT_NAME}-$(date +%Y%m%d-%H%M%S).log"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "${LOG_FILE}"; }
info() { log "INFO  $*"; }
warn() { log "WARN  $*"; }
err() { log "ERROR $*"; exit 1; }

# Pré-requis : binaire présent.
require() {
  command -v "$1" >/dev/null 2>&1 || err "commande requise absente : $1"
}

# Pré-requis : cluster joignable via kubectl.
check_cluster() {
  kubectl cluster-info >/dev/null 2>&1 || err "cluster inaccessible (context kubectl ?)"
}