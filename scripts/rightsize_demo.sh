#!/usr/bin/env bash
#
# Démonstration FinOPS : rightsizing de team-checkout (volontairement
# sur-dimensionné) et estimation de l'économie mensuelle.
#
# Usage :
#   ./scripts/rightsize_demo.sh            # applique 100m/256Mi
#   ./scripts/rightsize_demo.sh --revert   # restaure 1 CPU / 2Gi
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require kubectl
check_cluster

NS="team-checkout"
DEPLOY="checkout-api"
PRICING="${SCRIPT_DIR}/../kubecost/cloud-pricing.yaml"

REVERT=false
[[ "${1:-}" == "--revert" ]] && REVERT=true

# Tarifs mensuels lus depuis le pricing custom (source unique de vérité).
CPU_MONTH="$(sed -nE 's/^[[:space:]]*CPU: *"([0-9.]+)".*/\1/p' "${PRICING}" | head -1)"
RAM_MONTH="$(sed -nE 's/^[[:space:]]*RAM: *"([0-9.]+)".*/\1/p' "${PRICING}" | head -1)"

if [[ "${REVERT}" == "true" ]]; then
  info "==> restauration de la configuration initiale (1 CPU / 2Gi)"
  kubectl -n "${NS}" set resources deployment/"${DEPLOY}" \
    --requests=cpu=1,memory=2Gi --limits=cpu=1,memory=2Gi >/dev/null
  kubectl -n "${NS}" rollout status deployment/"${DEPLOY}" --timeout=120s >/dev/null
  info "==> configuration d'origine restaurée"
  exit 0
fi

info "==> requests actuelles :"
kubectl -n "${NS}" get deployment "${DEPLOY}" \
  -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'

info "==> application du rightsizing (100m CPU / 256Mi)"
kubectl -n "${NS}" set resources deployment/"${DEPLOY}" \
  --requests=cpu=100m,memory=256Mi --limits=cpu=200m,memory=256Mi >/dev/null
kubectl -n "${NS}" rollout status deployment/"${DEPLOY}" --timeout=120s >/dev/null

python3 - "${CPU_MONTH}" "${RAM_MONTH}" <<'PY'
import sys

cpu_month, ram_month = float(sys.argv[1]), float(sys.argv[2])
delta_cpu = 1.00 - 0.10   # 1 vCPU -> 100m
delta_ram = 2.0 - 0.25    # 2 GiB  -> 256Mi
cpu_saving = delta_cpu * cpu_month
ram_saving = delta_ram * ram_month
print(f"Ressources libérées : {delta_cpu:.2f} vCPU + {delta_ram:.2f} GiB par replica")
print(f"Économie estimée    : {cpu_saving:.2f} $ (CPU) + {ram_saving:.2f} $ (RAM) "
      f"= {cpu_saving + ram_saving:.2f} $/mois par replica")
PY
info "==> rightsizing appliqué ; l'allocation baissera sur la prochaine fenêtre Kubecost"