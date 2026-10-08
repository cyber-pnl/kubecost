#!/usr/bin/env bash
#
# Installe / met à jour Kubecost sur le cluster k3d local.
# Idempotent : réexécutable pour appliquer un changement de values/pricing.
#
set -euo pipefail

RELEASE="${KUBECOST_RELEASE:-kubecost}"
NAMESPACE="${KUBECOST_NAMESPACE:-kubecost}"
# 2.9.x est un chart de migration vers 3.0 qui exige un object-store
# (global federated-store) : on reste sur la dernière 2.8.x standalone.
CHART_VERSION="${KUBECOST_CHART_VERSION:-2.8.7}"
REPO_NAME="kubecost"
REPO_URL="https://kubecost.github.io/cost-analyzer/"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v helm >/dev/null || { echo "helm introuvable" >&2; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl introuvable" >&2; exit 1; }

echo "==> Dépôt Helm ${REPO_NAME} (${REPO_URL})"
helm repo add "${REPO_NAME}" "${REPO_URL}" >/dev/null 2>&1 || true
helm repo update "${REPO_NAME}" >/dev/null

echo "==> Namespace ${NAMESPACE}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo "==> Déploiement Kubecost ${CHART_VERSION} (release ${RELEASE})"
helm upgrade --install "${RELEASE}" "${REPO_NAME}/cost-analyzer" \
  --namespace "${NAMESPACE}" \
  --version "${CHART_VERSION}" \
  -f "${SCRIPT_DIR}/values.yaml" \
  -f "${SCRIPT_DIR}/cloud-pricing.yaml" \
  --timeout 15m

echo "==> Attente du rollout du cost-analyzer"
kubectl -n "${NAMESPACE}" rollout status "deploy/${RELEASE}-cost-analyzer" --timeout=15m

echo "==> État des pods"
kubectl -n "${NAMESPACE}" get pods

cat <<EOF

Kubecost installé. Accès dashboard (port-forward uniquement, cf. AGENTS.md) :

  kubectl -n ${NAMESPACE} port-forward svc/${RELEASE}-cost-analyzer 9090:9090
  # puis ouvrir http://localhost:9090

API d'allocation (= base du chargeback) :

  kubectl -n ${NAMESPACE} port-forward svc/${RELEASE}-cost-analyzer 9090:9090 &
  curl -s "http://localhost:9090/model/allocation?window=1d&aggregate=label:team"

Note : les premières données d'allocation apparaissent après ~15 min de collecte.
EOF
