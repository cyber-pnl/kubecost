# cluster/ — Provisioning k3d

Contient tout ce qui concerne la **création et la destruction du cluster k3d** multi-node.

| Fichier | Rôle |
|---|---|
| `k3d-config.yaml` | Configuration déclarative k3d v1alpha5 : 1 server + 3 agents, API server sur 7443 |
| `setup-cluster.sh` | Provisioning (idempotent) + attente nodes Ready + vérification metrics-server |
| `teardown-cluster.sh` | Suppression propre du cluster (nom par défaut : `kubecost-lab`) |

## Commande de référence

```bash
./cluster/setup-cluster.sh          # créer / réutiliser le cluster
./cluster/teardown-cluster.sh       # supprimer le cluster
```

## Topologie actuelle

- **1 server** (`k3d-kubecost-lab-server-0`) = control plane
- **3 agents** (`agent-0`, `agent-1`, `agent-2`)
- **API server** : hôte `0.0.0.0:7443`
  - 6443 est utilisé par le k3s système de la machine → 7443 pour éviter le conflit
- **metrics-server** : actif (k3s l'embarque), `kubectl top` fonctionnel
- **traefik** : désactivé (inutile pour ce lab) — `servicelb` reste actif pour les Services LoadBalancer
- **Dashboard Kubecost** : volontairement non exposé (règle AGENTS.md)

## Règles

- Reproducibilité : le cluster est recréable à l'identique depuis `k3d-config.yaml`.
- Aucun port public n'expose Kubecost (port-forward uniquement).
- Voir [docs/agents/rules.md](../docs/agents/rules.md) → `Cluster (k3d)`.