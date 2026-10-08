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

## Déploiement

`kubectl apply -R -f teams/` trie les fichiers par ordre alphabétique : les
`deployment.yaml` passent **avant** leur `namespace.yaml`. Appliquer donc en
deux passes (ou namespaces d'abord) :

```bash
kubectl apply -R -f teams/            # 1re passe : crée les namespaces
kubectl apply -R -f teams/            # 2e passe : crée les workloads
```

Vérif :

```bash
kubectl get pods -A | grep team-
kubectl -n team-catalog get hpa
```

## Notes d'environnement

- Le LB orphelin de `team-search` écoute sur le **port 8081** (et non 80) :
  le `my-wordpress` du namespace `default` (hors scope lab) bind déjà le
  host port 80 sur les 4 nodes via klipper-lb → un 2e LB sur 80 resterait
  `Pending` (conflit de ports).