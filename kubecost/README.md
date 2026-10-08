# kubecost/ — Installation & pricing Kubecost

Installation Helm de Kubecost et configuration du **pricing custom** nécessaire à un cluster k3d (qui n'a aucun billing cloud réel).

| Fichier | Rôle |
|---|---|
| `install-kubecost.sh` | Helm repo + installation du chart `cost-analyzer` (idempotent) |
| `values.yaml` | Config allégée : allocation par label, Grafana/forecasting off, ClusterIP |
| `cloud-pricing.yaml` | Tarif custom on-prem : vCPU, Gi RAM, Gi storage, réseau |

## Déploiement

```bash
./kubecost/install-kubecost.sh
```

Installé avec la release `kubecost` dans le namespace `kubecost` (chart `2.8.7`).

> **Pourquoi 2.8.7 et pas 2.9.7 ?** La 2.9.x est un chart de migration vers Kubecost 3.0
> qui **exige un object-store** (`global federated-store`) ; 2.8.7 est la dernière
> version 2.x autonome (aucune dépendance externe). Voir `docs/roadmap.md` Phase 2.

## Composants déployés

Deux Deployments seulement (config allégée pour un hôte contraint) :

- `kubecost-cost-analyzer` — pod 4 conteneurs : cost-model, frontend, aggregator
  (query backend) et cloud-cost.
- `kubecost-prometheus-server` — Prometheus embarqué (retention 7j, sans PVC).

Le cost-model **émet lui-même les métriques de type kube-state-metrics**
(`kube_pod_labels`, `container_cpu_allocation`, `node_cpu_hourly_cost`…),
donc `kube-state-metrics` n'est pas déployé séparément.

## Pricing custom on-prem

`cloud-pricing.yaml` définit `kubecostProductConfigs.defaultModelPricing`
(prix mensuels, base 730 h). Appliqué et vérifié :

| Ressource | Prix affiché | Dérivé du tarif |
|---|---|---|
| `node_cpu_hourly_cost` | `0.041096` | `CPU=30.0` $/vCPU-mois ÷ 730 |
| `node_ram_hourly_cost` | `0.005479` | `RAM=4.0` $/GiB-mois ÷ 730 |

`/model/clusterInfo` renvoie bien `provider: custom`.

## Accès (port-forward uniquement — cf. AGENTS.md)

```bash
kubectl -n kubecost port-forward svc/kubecost-cost-analyzer 9090:9090
# Dashboard → http://localhost:9090
```

## API

```bash
curl "http://localhost:9090/model/allocation?window=1d&aggregate=label:team"
```

> Les premières données d'allocation apparaissent après ~15–25 min de collecte.
> Les workloads d'équipe (labels `team`/`product`/`env`) arrivent en Phase 3.

## Règles

- Ne jamais exposer le dashboard publiquement → uniquement `port-forward`.
- Tarif custom obligatoire → voir [docs/finops-practices.md](../docs/finops-practices.md).
- Règles détaillées : [docs/agents/rules.md](../docs/agents/rules.md) → `Kubecost & pricing`.
