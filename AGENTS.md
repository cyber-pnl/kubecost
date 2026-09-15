# AGENTS.md - Guide Agent

Point d'entrée pour tout agent travaillant sur ce dépôt. **Lisez ce fichier puis les fichiers référencés avant toute action.**

## Contexte du projet

**Kubecost Multi-Tenant Cost Allocation Lab** — démontrer l'allocation de coûts Kubernetes, le chargeback et les pratiques FinOPS via un cluster k3d partagé par 4 équipes fictives aux comportements de consommation volontairement différents.

**Objectif primaire** : « qui coûte quoi, et pourquoi ? » dans un cluster Kubernetes partagé, à travers des patterns de coût observables.

## Conventions obligatoires (non négociables)

### 1. Conventional Commits
Tout commit DOIT suivre `type(scope): description`.

```bash
feat(cluster): add k3d multi-node configuration
fix(kubecost): adjust custom pricing formula
docs(chargeback): update API integration guide
```

- **Types** : `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`, `perf`
- **Scopes** : `cluster`, `kubecost`, `teams`, `scripts`, `chargeback`, `finops`, `docs`, `ci`, `deps`
- Validation automatisée : voir `.commitlintrc`

### 2. Labels requis sur toute ressource Kubernetes
- `team` (ex : `team-checkout`)
- `product` (ex : `checkout-api`)
- `env` (ex : `lab`, `demo`)

### 3. Ressources sur tous les conteneurs
- `resources.requests.cpu` / `resources.requests.memory`
- `resources.limits.cpu` / `resources.limits.memory`
- Le sur-dimensionnement intentionnel DOIT être documenté (commentaire dans le manifest)

### 4. Structure du dépôt — ne pas réinventer
```
cluster/        # Provisioning k3d
kubecost/       # Installation Kubecost + pricing
teams/          # Workloads simulés (4 équipes)
scripts/        # Simulations + reset
chargeback/     # Extraction API + rapports
docs/           # Architecture, scénarios, FinOPS, roadmap, guide agent
```

---

## Orientation vers les guides détaillés

| Fichier | Pourquoi le consulter |
|---|---|
| [docs/agents/skills.md](docs/agents/skills.md) | **Compétences requises** par domaine (k3d, Kubecost, simulation, chargeback, FinOPS) |
| [docs/agents/rules.md](docs/agents/rules.md) | **Règles détaillées** par domaine (cluster, kubecost, teams, chargeback, docs…) |
| [docs/agents/workflows.md](docs/agents/workflows.md) | **Workflows** (dev, démo, troubleshooting), benchmarks, escalade, maintenance |
| [docs/architecture.md](docs/architecture.md) | Architecture technique + schémas Mermaid |
| [docs/scenarios.md](docs/scenarios.md) | Les 4 scénarios simulés et résultats attendus |
| [docs/roadmap.md](docs/roadmap.md) | Phases restantes pour compléter le projet |
| [README.md](README.md) | Vue d'ensemble du projet |

---

## Règles de sécurité (toujours)

- Ne jamais commiter de secrets ou credentials
- Accès dashboard via `kubectl port-forward` uniquement (jamais exposé publiquement)
- RBAC avec privilèges minimaux
- Scanner les images pour vulnérabilités

## Commandes de qualité

- Scripts bash : `set -euo pipefail`
- Python : PEP 8 + type hints
- YAML : valider avec `yamllint`
- Avant de clôturer une tâche : exécuter lint/validation si applicable