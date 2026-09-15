# scripts/ — Simulations de comportement & reset

Scripts Bash rejouables qui déclenchent les comportements de coût à observer dans Kubecost. Chaque script journalise son **heure de lancement** dans `scripts/logs/` pour corréler l'action au dashboard.

| Script (à créer — voir [roadmap](../docs/roadmap.md) Phase 4) | Effet |
|---|---|
| `common.sh` | Helpers : logging horodaté, checks préalables |
| `simulate_overprovisioning.sh` | Applique `team-checkout` (requests très hautes, usage minime) |
| `simulate_traffic_spike.sh` | Job k6/hey + scaling HPA sur `team-catalog` |
| `simulate_orphan_resources.sh` | Création PVC détaché, LoadBalancer sans backend, Job terminé |
| `simulate_idle_waste.sh` | Pods 24/7 au repos avec requests élevées |
| `reset_scenario.sh` | Nettoyage complet des namespaces (rejouable démo) |
| `demo_full.sh` | Enchaîne reset → deploy → simulations → rapport (Phase 6) |

## Exemple d'usage

```bash
# Ajouter au PATH pour la démo
export PATH="$PWD:$PATH"
./scripts/simulate_traffic_spike.sh
```

## Règles

- `set -euo pipefail` sur tous les scripts.
- Idempotents : rejouables sans effet de bord.
- Logs horodatés dans `scripts/logs/`.
- Pas de chemins absolus en dur.
- Détails : [docs/agents/workflows.md](../docs/agents/workflows.md).