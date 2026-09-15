# team-search — Ressources orphelines

**Pattern de coût** : ressources provisionnées sans consommateur actif — PVC détaché, LoadBalancer sans backend, Jobs terminés jamais nettoyés.

**Signal Kubecost attendu** : coûts « cachés » (stockage, réseau) visibles via `/model/assets`, que personne ne surveille naturellement.

## Fichiers (à créer — Phase 3)

- `namespace.yaml` — labels + ResourceQuota + LimitRange
- `deployment.yaml` — `postgres` (petite instance, réellement inutilisée)
- `pvc.yaml` — PersistentVolumeClaim (volontairement non consommé)
- `service-loadbalancer.yaml` — Service type LoadBalancer sans backend
- `behavior.md` — description du comportement simulé

## Script lié

`scripts/simulate_orphan_resources.sh` — scénario détaillé : [docs/scenarios.md](../../docs/scenarios.md).