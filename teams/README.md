# teams/ — Workloads simulés (4 équipes)

Namespaces et workloads des 4 équipes fictives. Chaque équipe a un **profil de consommation volontairement différent** pour rendre les patterns FinOPS observables dans Kubecost.

| Dossier | Équipe | Pattern de coût |
|---|---|---|
| `team-checkout/` | Checkout | Over-provisioning (requests >> usage) |
| `team-catalog/` | Catalog | Traffic spikes + HPA (1→10 replicas) |
| `team-search/` | Search | Ressources orphelines (PVC, LB, Jobs) |
| `team-platform/` | Platform | Baseline efficace (requests = usage) |

## Contenu attendu par équipe (voir [roadmap](../docs/roadmap.md) Phase 3)

- `namespace.yaml` — labels `team/product/env` + `ResourceQuota` + `LimitRange`
- `deployment.yaml` — workloads légers avec `requests`/`limits` commentés
- `behavior.md` — comportement simulé + signal Kubecost attendu
- (catalog) `horizontalpodautoscaler.yaml`

## Règles

- Toute ressource : labels `team`, `product`, `env`.
- Tout conteneur : `requests` **et** `limits` (cpu + mémoire).
- Sur-dimensionnement intentionnel documenté en commentaire.
- Scénarios détaillés : [docs/scenarios.md](../docs/scenarios.md).
- Règles détaillées : [docs/agents/rules.md](../docs/agents/rules.md) → `Équipes simulées`.