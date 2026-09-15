# team-catalog — Traffic spikes

**Pattern de coût** : pics de trafic scriptés → scaling horizontal HPA (1→10 replicas).

**Signal Kubecost attendu** : variation du coût dans le temps, impact financier de l'autoscaling maîtrisé.

## Fichiers (à créer — Phase 3)

- `namespace.yaml` — labels + ResourceQuota + LimitRange
- `deployment.yaml` — `nginx`/`httpbin`, requests raisonnables + probes
- `horizontalpodautoscaler.yaml` — HPA ciblant ~60 % CPU
- `behavior.md` — description du comportement simulé

## Scripts liés

- `scripts/simulate_traffic_spike.sh` — lance Job `k6`/`hey` + scaling
- scénario détaillé : [docs/scenarios.md](../../docs/scenarios.md)