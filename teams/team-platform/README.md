# team-platform — Baseline efficace

**Pattern de coût** : stack de référence où `requests` = usage réel et charge stable → baseline à ~100 % d'efficience.

**Rôle** : servir de point de comparaison pour juger le gaspillage des autres équipes.

## Fichiers (à créer — Phase 3)

- `namespace.yaml` — labels + ResourceQuota + LimitRange
- `deployment.yaml` — `nginx` bien dimensionné (requests = usage, probes)
- `behavior.md` — description du comportement de référence

## Profil ressources (mature)

```yaml
# baseline intent: requests alignés sur l'usage mesuré
resources:
  requests:
    cpu: "100m"
    memory: "256Mi"
  limits:
    cpu: "200m"
    memory: "384Mi"
```

## Scénario

Voir [docs/scenarios.md](../../docs/scenarios.md) — équipe de référence.