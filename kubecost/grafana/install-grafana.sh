#!/usr/bin/env bash
#
# Installe Grafana (dashboards FinOPS) branché sur le Prometheus de Kubecost.
# Idempotent : ré-exécutable pour mettre à jour le chart ou le dashboard.
#
# Usage : ./kubecost/grafana/install-grafana.sh
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "${SCRIPT_DIR}/../../scripts/common.sh"

require helm
require kubectl
check_cluster

NS="kubecost"
RELEASE="grafana"
CHART_VERSION="${GRAFANA_CHART_VERSION:-10.5.15}"

info "==> dépôt Helm Grafana"
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null

info "==> installation/mise à jour de Grafana (chart ${CHART_VERSION})"
helm upgrade --install "${RELEASE}" grafana/grafana \
  --namespace "${NS}" --create-namespace \
  --version "${CHART_VERSION}" \
  -f "${SCRIPT_DIR}/values.yaml" \
  --wait --timeout 5m >/dev/null

info "==> dashboard FinOPS (ConfigMap sidecar)"
kubectl -n "${NS}" create configmap grafana-dashboard-kubecost \
  --from-file=kubecost-teams.json="${SCRIPT_DIR}/dashboard.json" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "${NS}" label configmap grafana-dashboard-kubecost \
  grafana_dashboard=1 --overwrite >/dev/null

info "==> Grafana accessible via port-forward :"
info "    kubectl -n ${NS} port-forward svc/${RELEASE} 3000:80"
info "    http://localhost:3000  (dashboard: 'Kubecost — Coûts par equipe')"
info "    identifiants admin :"
info "      user : admin"
info "      pass : kubectl -n ${NS} get secret ${RELEASE} -o jsonpath='{.data.admin-password}' | base64 -d"
info "==> Installation terminée"
