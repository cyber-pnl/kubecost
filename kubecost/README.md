# kubecost/ — Installation & pricing Kubecost

Contient l'installation Helm de Kubecost et la configuration du **pricing custom** nécessaire à un cluster k3d (qui n'a aucun billing cloud réel).

| Fichier (à créer — voir [roadmap](../docs/roadmap.md) Phase 2) | Rôle |
|---|---|
| `install-kubecost.sh` | Helm repo + installation du chart `cost-analyzer` |
| `values.yaml` | Allocation par namespace/label/annotation, retention, service ClusterIP |
| `cloud-pricing.yaml` | Tarif custom on-prem : vCPU/h, Gi RAM/h, Gi storage/h, réseau |

## Accès

```bash
kubectl port-forward svc/kubecost-cost-analyzer -n kubecost 9090:9090
# Dashboard → http://localhost:9090
```

## API

```bash
curl "http://localhost:9090/model/allocation?window=15m&aggregate=namespace"
```

## Règles

- Ne jamais exposer le dashboard publiquement → uniquement `port-forward`.
- Tarif custom obligatoire → voir [docs/finops-practices.md](../docs/finops-practices.md).
- Règles détaillées : [docs/agents/rules.md](../docs/agents/rules.md) → `Kubecost & pricing`.