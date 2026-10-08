# team-checkout — Over-provisioning

## Comportement simulé

L'équipe Checkout déploie une API REST (`hashicorp/http-echo`) avec des
`requests` volontairement très supérieures à l'usage réel :

- **requests / limits** : `1 CPU` / `2Gi`
- **usage réel attendu** : `~0.1 CPU` / `~256Mi`

Kubecost facture l'allocation sur le **max(requests, usage)** : le coût
*alloué* est donc ~10× le coût réellement *utilisé* → gaspillage visible.

## Signal Kubecost attendu

| Indicateur | Attendu |
|---|---|
| Coût alloué vs utilisé | écart très élevé (alloué >> utilisé) |
| Recommandation rightsizing | ~0.1 CPU / 256Mi |
| Efficiency score | < 20 % |
| Vue | `allocation?aggregate=label:team` et Savings → rightsizing |

## Scénario lié

- [docs/scenarios.md](../../docs/scenarios.md) — Scénario 1 (Over-provisioning)
- Script : `scripts/simulate_overprovisioning.sh` (Phase 5)

## Fichiers

- `namespace.yaml` — Namespace + ResourceQuota + LimitRange
- `deployment.yaml` — Deployment `checkout-api` + Service ClusterIP

## Déploiement

```bash
kubectl apply -f teams/team-checkout/
```
