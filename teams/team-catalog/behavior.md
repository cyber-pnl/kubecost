# team-catalog — Traffic spikes + HPA

## Comportement simulé

L'équipe Catalog expose une API (`nginx`) avec des resources **raisonnables**
et un `HorizontalPodAutoscaler` qui absorbe les pics de trafic :

- **requests / limits** : `100m` / `200m` CPU, `128Mi` / `256Mi` mémoire
- **HPA** : `minReplicas: 1`, `maxReplicas: 10`, cible `60 %` CPU
- Un générateur de charge (`k6`/`hey`, Phase 5) provoque un pic scripté.

Kubecost voit le coût **croître pendant le pic** (plus de replicas actifs)
puis revenir à la baseline après stabilisation.

## Signal Kubecost attendu

| Indicateur | Attendu |
|---|---|
| Coût dans le temps | croissance nette pendant le pic, retour baseline |
| Replicas observés | 1 → 10 → 1 |
| Efficiency pendant le pic | élevée (ressources réellement utilisées) |
| Vue | `allocation?aggregate=label:team` sur fenêtre glissante |

## Scénario lié

- [docs/scenarios.md](../../docs/scenarios.md) — Scénario 2 (Traffic spike)
- Script : `scripts/simulate_traffic_spike.sh` (Phase 5)

## Fichiers

- `namespace.yaml` — Namespace + ResourceQuota + LimitRange
- `deployment.yaml` — Deployment `catalog-api` + Service ClusterIP + probes
- `horizontalpodautoscaler.yaml` — HPA `autoscaling/v2`

## Déploiement

```bash
kubectl apply -f teams/team-catalog/
kubectl -n team-catalog get hpa catalog-api -w
```
