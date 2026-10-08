#!/usr/bin/env bash
#
# Simule le pattern RESSOURCES ORPHELINES (team-search) :
#   - PVC search-data-orphan bindé puis laissé sans consommateur
#   - Service LoadBalancer sans backend
#   - Job terminé jamais nettoyé (+ postgres idle)
# Effet attendu dans Kubecost : coûts Storage/Network via /model/assets.
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require kubectl
check_cluster

info "==> team-search : postgres idle + PVC orphelin + LB sans backend"
kubectl apply -R -f "${REPO_ROOT}/teams/team-search/" >/dev/null
kubectl -n team-search rollout status deploy/search-db --timeout=120s >/dev/null

info "==> Binding du PVC orphelin via un pod éphémère (puis suppression)"
kubectl apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pvc-binder
  namespace: team-search
  labels:
    team: team-search
    product: search-db
    env: lab
spec:
  restartPolicy: Never
  containers:
    - name: binder
      image: busybox:1.36
      command: ["sh", "-c", "touch /data/.bound && sleep 1"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: search-data-orphan
EOF
kubectl -n team-search wait --for=jsonpath='{.status.phase}'=Succeeded pod/pvc-binder --timeout=120s >/dev/null
kubectl delete pod pvc-binder -n team-search >/dev/null

info "==> Job terminé laissé volontairement non nettoyé"
kubectl delete job orphan-job -n team-search --ignore-not-found >/dev/null
kubectl apply -f - >/dev/null <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: orphan-job
  namespace: team-search
  labels:
    team: team-search
    product: search-db
    env: lab
spec:
  # TTL en secondes : 7 jours => visible longtemps et jamais nettoyé en démo
  ttlSecondsAfterFinished: 604800
  template:
    metadata:
      labels:
        team: team-search
        product: search-db
        env: lab
    spec:
      restartPolicy: Never
      containers:
        - name: worker
          image: busybox:1.36
          command: ["sh", "-c", "echo orphan-done"]
EOF

info "==> État final (PVC doit être Bound, LB avec IP, Job Completed) :"
kubectl get pvc,svc,job -n team-search >>"${LOG_FILE}" 2>&1
info "LOG=${LOG_FILE}"