# scripts/ — Simulations de comportement & reset

Scripts Bash **rejouables** qui déclenchent les comportements de coût à observer dans Kubecost. Chaque script journalise son **heure de lancement** dans `scripts/logs/` pour corréler l'action au dashboard.

| Script | Effet |
|---|---|
| `common.sh` | Helpers : logging horodaté, pré-requis (`set -euo pipefail`) |
| `deploy_teams.sh` | Déploie les 4 équipes (2 passes : namespaces puis workloads) |
| `simulate_overprovisioning.sh` | Applique `team-checkout` (requests très hautes, usage minime) |
| `simulate_traffic_spike.sh` | Job `hey` + scaling HPA sur `team-catalog` |
| `simulate_orphan_resources.sh` | PVC détaché (bind), LoadBalancer sans backend, Job terminé |
| `simulate_idle_waste.sh` | Pods 24/7 au repos avec requests élevées |
| `rightsize_demo.sh` | Rightsizing `team-checkout` + estimation d'économie (`--revert`) |
| `reset_scenario.sh` | Nettoyage complet des namespaces (rejouable démo) |
| `demo_full.sh` | Enchaîne reset → deploy → simulations → rapport (Phase 6) |

## Usage

```bash
./scripts/simulate_overprovisioning.sh
./scripts/simulate_traffic_spike.sh          # défaut : 5 min, conc 200, 1000 req/s
SPIKE_RATE=3000 SPIKE_DURATION=30s ./scripts/simulate_traffic_spike.sh
./scripts/simulate_orphan_resources.sh
./scripts/reset_scenario.sh
```

Chaque exécution écrit un log horodaté dans `scripts/logs/`.

## Notes d'implémentation (mesurées sur le lab)

- **HPA `team-catalog`** : nginx est très efficace ; un petit débit ne déclenche
  pas le scaling. Avec `conc=200` / `rate=1000` on observe une montée
  **1 → 4 → 8 replicas** (nginx bloqué à ses limits 200m). Adapter `SPIKE_RATE`
  pour atteindre 10.
- **PVC orphelin** : le provisioner `local-path` est en `WaitForFirstConsumer` :
  `simulate_orphan_resources.sh` crée un pod éphémère pour le binder puis le
  supprime (PVC laissé `Bound` sans consommateur).
- **LB orphelin** : écoute en **8081** (le `my-wordpress` du ns `default` bind
  déjà le host port 80 sur les 4 nodes via klipper-lb).

## Règles

- `set -euo pipefail` sur tous les scripts.
- Idempotents : rejouables sans effet de bord.
- Logs horodatés dans `scripts/logs/`.
- Pas de chemins absolus en dur.
- Détails : [docs/agents/workflows.md](../docs/agents/workflows.md).