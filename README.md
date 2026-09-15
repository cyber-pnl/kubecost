# Kubecost Multi-Tenant Cost Allocation Lab

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.26+-326CE5.svg?logo=kubernetes)](https://kubernetes.io)
[![Kubecost](https://img.shields.io/badge/Kubecost-2.0+-FF6B35.svg)](https://kubecost.com)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg)](https://conventionalcommits.org)

Un cluster Kubernetes partagé et simulé (k3d), avec des équipes fictives aux comportements de consommation volontairement différents, pour démontrer la valeur de **Kubecost** en matière d'**allocation de coûts**, de **chargeback** et de **détection de gaspillage**.

**Objectif** : répondre à la question *"qui coûte quoi, et pourquoi ?"* via des patterns de coût observables et reproductibles.

---

## Démarrage rapide

```bash
# 1. Provisionner le cluster k3d
./cluster/setup-cluster.sh

# 2. Installer Kubecost + pricing custom
./kubecost/install-kubecost.sh

# 3. Déployer les 4 équipes simulées
kubectl apply -f teams/

# 4. Lancer les simulations de comportement
./scripts/simulate_overprovisioning.sh
./scripts/simulate_traffic_spike.sh
./scripts/simulate_orphan_resources.sh

# 5. Générer les rapports de chargeback
python chargeback/fetch_kubecost_api.py
python chargeback/generate_report.py
```

---

## Vue d'ensemble

```mermaid
graph TB
    subgraph "Cluster k3d"
        subgraph "K8s Control Plane"
            API["API Server + etcd + scheduler"]
        end

        subgraph "Equipes simulées (namespaces)"
            CO["team-checkout<br/>Over-provisioning"]
            CA["team-catalog<br/>Traffic spikes (HPA)"]
            SE["team-search<br/>Ressources orphelines"]
            PL["team-platform<br/>Baseline efficace"]
        end
    end

    subgraph "Observabilité & Coûts"
        PROM["Prometheus"]
        MET["Metrics Server"]
        KC["Kubecost"]
    end

    subgraph "Facturation interne"
        API_K["/model/allocation"]
        FETCH["fetch_kubecost_api.py"]
        REPORT["generate_report.py"]
        OUT["Rapports CSV/HTML"]
    end

    API --> PROM
    MET --> PROM
    CO --> PROM
    CA --> PROM
    SE --> PROM
    PL --> PROM
    PROM --> KC
    KC --> API_K
    API_K --> FETCH
    FETCH --> REPORT
    REPORT --> OUT
```

---

## Structure du projet

```
kubecost-multitenant-lab/
├── README.md                # This file (overview)
├── AGENTS.md                # Règles & conventions pour agents
├── .commitlintrc            # Validation Conventional Commits
├── cluster/                 # Provisioning k3d (config + scripts)
├── kubecost/                # Installation Helm + pricing custom
├── teams/                   # 4 équipes simulées (namespaces + workloads)
│   ├── team-checkout/
│   ├── team-catalog/
│   ├── team-search/
│   └── team-platform/
├── scripts/                 # Simulations de comportement + reset
├── chargeback/              # Extraction API + génération de rapports
└── docs/                    # Architecture, scénarios, FinOPS, roadmap
```

---

## Documentation

| Doc | Contenu |
|---|---|
| [docs/architecture.md](docs/architecture.md) | Architecture technique, data flow, modèle d'allocation |
| [docs/scenarios.md](docs/scenarios.md) | Les 4 équipes, scripts de simulation, résultats attendus |
| [docs/finops-practices.md](docs/finops-practices.md) | Bonnes pratiques FinOPS (showback → chargeback, rightsizing…) |
| [docs/roadmap.md](docs/roadmap.md) | Roadmap phase par phase pour compléter le projet |
| [docs/agents/](docs/agents/) | Skills, rules et workflows pour agents (voir AGENTS.md) |
| [AGENTS.md](AGENTS.md) | Point d'entrée agent : conventions et orientation |

---

## Le problème démontré en 1 image

Chaque équipe paie dans Kubecost ce qu'elle **réserve** (requests) vs ce qu'elle **utilise** :

| Équipe | Comportement | Signal Kubecost |
|---|---|---|
| `team-checkout` | Requests très hautes, usage minime | Écart coût alloué vs coût réel → rightsizing |
| `team-catalog` | Pics de trafic, HPA 1→10 replicas | Variation du coût dans le temps |
| `team-search` | PVC / LoadBalancer orphelins | Coûts cachés non nettoyés |
| `team-platform` | Requests = usage, charge stable | Baseline de référence (efficience 100 %) |

---

## Licence

MIT — voir [LICENSE](LICENSE).