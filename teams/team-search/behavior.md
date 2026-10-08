# team-search — Ressources orphelines

## Comportement simulé

L'équipe Search laisse traîner des ressources **provisionnées sans
consommateur actif** :

- **`search-db`** — petit `postgres:16` qui tourne mais ne reçoit aucune
  requête (aucun Service ClusterIP derrière).
- **`search-data-orphan` (PVC)** — volume de `5Gi` déclaré, jamais monté par
  un pod : coût de stockage "caché".
- **`search-lb-orphan` (Service LoadBalancer)** — `selector` vide : k3d
  (servicelb) assigne quand même une IP externe → coût réseau sans trafic.

Ces coûts n'apparaissent pas au premier regard dans le "cost by namespace" :
ils se voient via `/model/assets` (Storage + Network).

## Signal Kubecost attendu

| Indicateur | Attendu |
|---|---|
| Coût Storage | PVC `search-data-orphan` visible dans les assets malgré l'absence de pod |
| Coût Network | LoadBalancer avec IP externe attribué à `team-search` |
| Vue | `/model/assets?window=1d&aggregate=namespace` (Storage, Network) |
| Workload CPU | `search-db` quasi idle mais facturé (requests) |

## Scénario lié

- [docs/scenarios.md](../../docs/scenarios.md) — Scénario 3 (Ressources orphelines)
- Script : `scripts/simulate_orphan_resources.sh` (Phase 5)

## Fichiers

- `namespace.yaml` — Namespace + ResourceQuota (inclut storage + LB) + LimitRange
- `deployment.yaml` — Deployment `search-db` (postgres inutilisé, emptyDir)
- `pvc.yaml` — PVC `search-data-orphan` 5Gi, jamais monté
- `service-loadbalancer.yaml` — Service LoadBalancer sans backend

## Déploiement

```bash
kubectl apply -f teams/team-search/
kubectl -n team-search get pvc,svc
```