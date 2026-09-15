# Architecture technique

Architecture détaillée du **Kubecost Multi-Tenant Cost Allocation Lab**.

## Vue globale

```mermaid
graph TB
    subgraph "Cluster k3d"
        subgraph "Control Plane (1 server)"
            API["kube-apiserver"]
            ETCD["etcd"]
            SCH["scheduler"]
            CM["controller-manager"]
        end

        subgraph "Agents (3 nodes)"
            N1["node/agent-0"]
            N2["node/agent-1"]
            N3["node/agent-2"]
        end

        subgraph "Namespaces équipes"
            CO["team-checkout"]
            CA["team-catalog"]
            SE["team-search"]
            PL["team-platform"]
        end
    end

    subgraph "Observabilité"
        MET["metrics-server"]
        PROM["Prometheus (bundled Kubecost)"]
        KC["cost-analyzer<br/>(Kubecost + OpenCost)"]
    end

    subgraph "Couche Diffuser / Facturer"
        ALLOC["API /model/allocation"]
        ASSETS["API /model/assets"]
        FETCH["fetch_kubecost_api.py"]
        RPT["generate_report.py"]
        OUT["reports/ CSV + HTML"]
    end

    MET --> PROM
    API --> PROM
    N1 --> MET
    N2 --> MET
    N3 --> MET
    CO --> PROM
    CA --> PROM
    SE --> PROM
    PL --> PROM
    PROM --> KC
    KC --> ALLOC
    KC --> ASSETS
    ALLOC --> FETCH
    ASSETS --> FETCH
    FETCH --> RPT
    RPT --> OUT
```

## Déploiement logique des équipes

Chaque équipe est un namespace isolé (ResourceQuota + LimitRange) avec des workloads légers.

```mermaid
graph LR
    subgraph "team-checkout"
        CO_SVC["Service checkout-api"]
        CO_DEP["Deployment<br/>1-2 replicas<br/>requests: 1CPU/2Gi"]
        CO_HPA["HPA absent<br/>(sur-provisionné volontairement)"]
        CO_POD0["Pod (charge ~0.1 CPU)"]
    end

    subgraph "team-catalog"
        CA_SVC["Service catalog-api"]
        CA_DEP["Deployment<br/>replicas 1..10"]
        CA_HPA["HPA (cpu 60%)"]
        CA_POD["Pods + générateur k6/hey"]
    end

    subgraph "team-search"
        SE_SVC["Service search-db<br/>(LoadBalancer sans backend)"]
        SE_DEP["Deployment postgres"]
        SE_PVC["PVC orphelin"]
        SE_JOB["Job terminé non nettoyé"]
    end

    subgraph "team-platform"
        PL_SVC["Service platform-mon"]
        PL_DEP["Deployment nginx<br/>requests = usage"]
        PL_POD["Pods stables"]
    end

    CO_SVC --> CO_DEP --> CO_POD0
    CA_SVC --> CA_DEP --> CA_POD
    CA_HPA -.scales.-> CA_DEP
    SE_SVC -.aucun backend.-> X["(idle)"]
    SE_DEP --> SE_PVC
    PL_SVC --> PL_DEP --> PL_POD
```

## Flux de données de coût

```mermaid
sequenceDiagram
    actor User as SRE / démo
    participant S as Scripts (Bash)
    participant K as Cluster k3d
    participant P as Prometheus (Kubecost)
    participant KC as cost-analyzer / OpenCost
    participant API as REST API
    participant PY as chargeback (Python)
    participant RPT as rapports CSV/HTML

    User->>S: ./scripts/simulate_*.sh
    S->>K: kubectl apply / scale / create orphan
    K->>P: métriques (container_cpu, mem, pvc…)
    P->>KC: scraping 15 min
    KC->>API: exposition /model/allocation
    User->>API: curl ?window=1d&aggregate=namespace
    API-->>PY: fetch_kubecost_api.py
    PY->>PY: calcul allocation directe + partagée
    PY->>RPT: generate_report.py (CSV/HTML)
    RPT-->>User: facture interne par équipe
```

## Modèle d'allocation des coûts

```mermaid
pie title Répartition cible (après simulation)
    "team-checkout (sur-provisionné)" : 40
    "team-catalog (pics de trafic)" : 25
    "team-search (orphelins)" : 15
    "team-platform (baseline)" : 12
    "Partagé / idle (control plane)" : 8
```

### Règles d'allocation
1. **Direct** : CPU, mémoire, stockage, réseau par pod → namespace d'équipe.
2. **Partagé** : control plane, monitoring, ingress → réparti au prorata de la consommation.
3. **Idle** : capacité non utilisée → assignée au budget plateforme (explicite).
4. **Orphelin** : PVC / LB / Jobs détachés → identifiés, coût visible pour inciter au nettoyage.
5. **Reconcilication** : total alloué ≈ total cluster (< 5 % d'écart).

> Méthode conforme aux principes FinOps (allocation 100 %, pas de coût sans propriétaire).

## Stack technique

| Composant | Choix | Justification |
|---|---|---|
| Cluster | **k3d** (`--agents 3 --servers 1`) | Multi-node en quelques secondes, servicelb intégré, reset rapide |
| Monitoring de coûts | **Kubecost** (Helm, OpenCost engine) | Allocation + dashboard + API |
| Pricing | **Custom pricing config** | k3d n'a pas de billing cloud → tarif on-prem simulé |
| Génération de charge | **k6** / **hey** | Pics CPU réels pour scaling crédible |
| Scripts | **Bash** | Idempotents, logs horodatés |
| Chargeback | **Python** | PEP 8 + type hints, API Kubecost |

## Sécurité & critères d'exposition

- Dashboard uniquement via `kubectl port-forward`, jamais publié.
- RBAC minimal (service accounts par namespace).
- NetworkPolicy deny-all par défaut (si activé).
- Images scannées pour vulnérabilités.