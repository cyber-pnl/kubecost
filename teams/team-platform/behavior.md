# team-platform — Baseline efficace

## Comportement simulé

L'équipe Platform expose une stack de monitoring légère (`nginx`) avec les
`requests` **alignés sur l'usage mesuré** et une charge stable :

- **requests** : `100m` CPU / `256Mi`
- **limits** : `200m` CPU / `384Mi`
- Charge régulière et constante (probes + trafic de veille)

C'est l'**équipe de référence** : ~100 % d'efficience. Les écarts des autres
équipes se jugent **par rapport à cette baseline**.

## Signal Kubecost attendu

| Indicateur | Attendu |
|---|---|
| Efficiency score | ~100 % |
| Coût alloué vs utilisé | quasi identiques |
| Cours du coût | plat, sans pic |
| Vue | `allocation?aggregate=label:team` → comparer avec les autres équipes |

## Scénario lié

- [docs/scenarios.md](../../docs/scenarios.md) — Scénario 4 (Idle waste / baseline)
- Script : `scripts/simulate_idle_waste.sh` (Phase 5)

## Fichiers

- `namespace.yaml` — Namespace + ResourceQuota + LimitRange
- `deployment.yaml` — Deployment `platform-metrics` + Service ClusterIP

## Déploiement

```bash
kubectl apply -f teams/team-platform/
```