# cluster/ — Provisioning k3d

Contient tout ce qui concerne la **création et la destruction du cluster k3d** multi-node.

| Fichier (à créer — voir [roadmap](../docs/roadmap.md) Phase 1) | Rôle |
|---|---|
| `k3d-config.yaml` | Configuration déclarative : 1 server, 3 agents, ports, réseau |
| `setup-cluster.sh` | Provisioning + vérification (`kubectl get nodes`), install metrics-server |
| `teardown-cluster.sh` | Suppression propre du cluster |

## Commandes de référence

```bash
k3d cluster create kubecost-lab --config cluster/k3d-config.yaml
k3d cluster delete kubecost-lab
```

## Règles

- Reproducibilité : le cluster doit être recréable à l'identique depuis `k3d-config.yaml`.
- 3 agents pour un multi-node réaliste (`servicelb` k3s simulé pour les LoadBalancer).
- Voir [docs/agents/rules.md](../docs/agents/rules.md) → `Cluster (k3d)`.