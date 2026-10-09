# kubecost/grafana/ — Dashboards FinOPS (bonus Phase 7)

Grafana branché sur le **Prometheus embarqué par Kubecost** offre une vue
temps réel complémentaire des rapports de chargeback (CSV/HTML) :

- CPU **requests (alloué) vs usage** par équipe → sur-dimensionnement visible
- Mémoire (working set) par équipe
- Coût horaire par nœud + coût cluster total ($/h)
- Variation du coût dans le temps (pics HPA `team-catalog`)

## Contenu

| Fichier | Rôle |
|---|---|
| `values.yaml` | Chart Grafana allégé (pas de PVC, ressources limitées, datasource + sidecar) |
| `dashboard.json` | Dashboard « Kubecost — Coûts par equipe » |
| `install-grafana.sh` | Installe Grafana + provisionne le dashboard (idempotent) |

## Installation

```bash
./kubecost/grafana/install-grafana.sh

# Accès (port-forward uniquement)
kubectl -n kubecost port-forward svc/grafana 3000:80
# → http://localhost:3000
```

Identifiants admin (aucun secret en clair dans le repo) :

```bash
kubectl -n kubecost get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d
# user : admin
```

## Fonctionnement

- Le **datasource** pointe sur `kubecost-prometheus-server.kubecost` (source
  unique des métriques de coût : `node_total_hourly_cost`, `container_*`,
  `kube_pod_container_resource_requests`).
- Le **sidecar** Grafana charge automatiquement tout ConfigMap labellisé
  `grafana_dashboard: "1"` dans le namespace `kubecost` ; `install-grafana.sh`
  génère ce ConfigMap depuis `dashboard.json`.

## Notes

- Installation ~128 Mi de requests : compatible avec le lab (aucune pression
  mémoire observée sur le nœud k3d).
- Les métriques Kubecost dépendent du scraping Prometheus → les NetworkPolicies
  d'équipe autorisent explicitement le namespace `kubecost` (voir `teams/README.md`).
