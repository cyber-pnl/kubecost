# team-checkout — Over-provisioning

**Pattern de coût** : requests très élevées (1 CPU / 2Gi) pour un usage réel minime (~0.1 CPU).

**Signal Kubecost attendu** : écart coût alloué vs coût utilisé → candidat n°1 au rightsizing.

## Fichiers (à créer — Phase 3)

- `namespace.yaml` — labels + ResourceQuota + LimitRange
- `deployment.yaml` — `hashicorp/http-echo`, requests sur-dimensionnées commentées
- `behavior.md` — description du comportement simulé

## Profil ressources (intentionnel)

```yaml
# over-provisioning intent: 1CPU/2Gi pour ~0.1CPU/256Mi d'usage réel (démo)
resources:
  requests:
    cpu: "1"
    memory: "2Gi"
  limits:
    cpu: "1"
    memory: "2Gi"
```

## Script lié

`scripts/simulate_overprovisioning.sh` — scénario détaillé : [docs/scenarios.md](../../docs/scenarios.md).