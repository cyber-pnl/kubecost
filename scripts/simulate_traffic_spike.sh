#!/usr/bin/env bash
#
# Simule le pattern TRAFFIC SPIKE : pic de charge sur team-catalog absorbé
# par le HPA (1 -> 10 replicas). Génère un Job `hey`, observe les replicas.
#
# Paramètres d'env (optionnels) :
#   SPIKE_DURATION       durée de la charge (défaut 5m)
#   SPIKE_CONCURRENCY    clients simultanés hey (défaut 200)
#   SPIKE_RATE           requêtes/s (défaut 1000)
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require kubectl
check_cluster

# Charge élevée par défaut : nginx est trop efficace pour déclencher le HPA
# avec un petit débit (replicas estimés 1->10). Ajuster si nécessaire.
SPIKE_DURATION="${SPIKE_DURATION:-5m}"
SPIKE_CONCURRENCY="${SPIKE_CONCURRENCY:-200}"
SPIKE_RATE="${SPIKE_RATE:-1000}"

info "==> team-catalog : HPA 1->10, cible 60 % CPU"
kubectl apply -R -f "${REPO_ROOT}/teams/team-catalog/" >/dev/null
kubectl -n team-catalog rollout status deploy/catalog-api --timeout=90s >/dev/null

BEFORE="$(kubectl -n team-catalog get hpa catalog-api -o jsonpath='{.status.currentReplicas}' 2>/dev/null || echo 1)"
info "==> Replicas avant pic : ${BEFORE}"

kubectl delete job traffic-spike -n team-catalog --ignore-not-found >/dev/null
info "==> Job hey : durée=${SPIKE_DURATION} conc=${SPIKE_CONCURRENCY} qps=${SPIKE_RATE}"
kubectl apply -f - >/dev/null <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: traffic-spike
  namespace: team-catalog
  labels:
    team: team-catalog
    product: catalog-api
    env: lab
spec:
  backoffLimit: 1
  ttlSecondsAfterFinished: 300
  template:
    metadata:
      labels:
        team: team-catalog
        product: catalog-api
        env: lab
    spec:
      restartPolicy: Never
      containers:
        - name: hey
          image: williamyeh/hey:latest
          args:
            - -z=${SPIKE_DURATION}
            - -c=${SPIKE_CONCURRENCY}
            - -q=${SPIKE_RATE}
            - http://catalog-api.team-catalog.svc/
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 128Mi
EOF

info "==> Observation replicas (30 s) :"
for _ in {1..6}; do
  R="$(kubectl -n team-catalog get hpa catalog-api -o jsonpath='{.status.currentReplicas}' 2>/dev/null || echo "?")"
  U="$(kubectl -n team-catalog get hpa catalog-api -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null || echo "?")"
  log "replicas=${R} cpu%=${U}"
  sleep 5
done
info "==> Pic en cours ; le HPA monte selon sa fenêtre d'observation."
info "LOG=${LOG_FILE}"