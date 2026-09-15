# Kubecost Multi-Tenant Cost Allocation Lab

Un cluster Kubernetes simulé, partagé par plusieurs équipes fictives aux comportements de consommation volontairement différents, pour démontrer concrètement la valeur de **Kubecost** en matière d'allocation de coûts, de chargeback et de détection de gaspillage.

## Objectif du projet

Répondre à la question **"qui coûte quoi, et pourquoi ?"** dans un cluster Kubernetes partagé, en s'appuyant sur des workloads simulés dont les comportements (sur-provisioning, pics de charge, ressources orphelines...) se traduisent visiblement dans le dashboard Kubecost.

Ce repo n'est pas un simple "hello world" Kubecost : c'est un **scénario piloté**, où chaque équipe fictive a un profil de comportement scripté et reproductible, afin que les résultats dans Kubecost racontent une histoire claire et démontrable.

---

## Stack technique

| Composant | Choix | Justification |
|---|---|---|
| Cluster Kubernetes | **k3d** | k3s packagé en conteneurs Docker : install en une commande, multi-nodes facile (`--agents 3`), load balancer intégré (`servicelb`) utile pour le scénario "ressources orphelines". Plus léger que k3s seul (pas de VM), plus complet que kind (pas de LB natif). |
| Monitoring de coûts | **Kubecost** (Helm) | Allocation des coûts par namespace/label/annotation, API exploitable pour le chargeback. |
| Pricing | **Custom pricing config** | k3d ne fournit aucune donnée de facturation réelle (contrairement à EKS/GKE) → configuration d'un tarif custom (prix vCPU/heure, Gi/heure) pour des coûts crédibles. |
| Génération de charge | `k6` / `hey` | Simuler de vrais pics CPU pour rendre le scaling crédible plutôt que purement artificiel. |
| Scripts de simulation | Bash | Déclenchement des comportements par équipe, logs horodatés. |
| Chargeback | Python | Extraction API Kubecost + génération de rapports par équipe. |

### Pourquoi k3d plutôt que kind ou k3s

- **kind** : pas de load balancer intégré par défaut (il faudrait ajouter MetalLB), moins pratique pour simuler du multi-node réaliste.
- **k3s seul** : conçu pour tourner sur de vraies VMs/machines, setup plus lourd (Multipass/Vagrant), plus long à réinitialiser pour rejouer la démo.
- **k3d** : le meilleur compromis vitesse d'installation / réalisme multi-node / compatibilité Kubecost.

Commande de démarrage type :
```bash
k3d cluster create kubecost-lab --agents 3 --servers 1
```

---

## Architecture du projet

```
kubecost-multitenant-lab/
├── README.md
├── cluster/
│   ├── k3d-config.yaml            # Config du cluster k3d (nodes, ports, réseau)
│   └── setup-cluster.sh           # Provisioning du cluster
├── kubecost/
│   ├── install-kubecost.sh        # Install via Helm
│   ├── values.yaml                # Config Helm (pricing, allocation, retention)
│   └── cloud-pricing.yaml         # Config pricing custom (mode on-prem/local)
├── teams/
│   ├── team-checkout/
│   │   ├── namespace.yaml
│   │   ├── deployment.yaml        # API REST, requests sur-dimensionnées
│   │   └── behavior.md            # Description du comportement simulé
│   ├── team-catalog/
│   │   ├── namespace.yaml
│   │   ├── deployment.yaml        # API + génération de charge (k6/hey)
│   │   └── behavior.md
│   ├── team-search/
│   │   ├── namespace.yaml
│   │   ├── deployment.yaml        # DB factice + PVC + LoadBalancer
│   │   └── behavior.md
│   └── team-platform/
│       ├── namespace.yaml
│       ├── deployment.yaml        # Stack bien dimensionnée (baseline)
│       └── behavior.md
├── scripts/
│   ├── simulate_overprovisioning.sh
│   ├── simulate_traffic_spike.sh
│   ├── simulate_orphan_resources.sh
│   ├── simulate_idle_waste.sh
│   ├── reset_scenario.sh
│   └── logs/
├── chargeback/
│   ├── fetch_kubecost_api.py      # Extraction des coûts via l'API Kubecost
│   ├── generate_report.py         # Génère un rapport mensuel par équipe
│   └── reports/                   # Rapports générés (CSV/HTML)
└── docs/
    ├── architecture.md
    ├── scenarios.md
    └── screenshots/
```

---

## Les 4 équipes simulées : workloads et comportements

Chaque équipe est un namespace avec des labels (`team`, `product`, `env`). Le contenu applicatif importe peu — ce qui compte pour Kubecost, c'est le **profil de ressources** (requests/limits vs usage réel), donc on privilégie des images légères et sans dépendance.

| Équipe | Namespace | Workload | Image | Comportement simulé | Signal attendu dans Kubecost |
|---|---|---|---|---|---|
| **Checkout** | `team-checkout` | API REST simple (Deployment + Service) | `hashicorp/http-echo` (ou petite app Node/Python custom) | Requests CPU/mémoire fixées très haut (ex: 1 CPU / 2Gi) pour une charge réelle minime | Écart important coût "alloué" vs coût "utilisé" → candidat n°1 au rightsizing |
| **Catalog** | `team-catalog` | API + génération de charge (Job `k6`/`hey`) | `nginx` ou `httpbin` | Pics de trafic déclenchés par script → scaling horizontal (1 à 10 replicas) | Variation du coût dans le temps, bon cas pour illustrer l'impact financier de l'autoscaling |
| **Search** | `team-search` | DB factice + PVC + Service LoadBalancer | `postgres` (petite instance, non réellement utilisée) | Ressources orphelines : PVC détaché, LoadBalancer sans backend, Jobs terminés non nettoyés | Coûts "cachés" que personne ne surveille naturellement |
| **Platform** | `team-platform` | Stack de monitoring légère | `prometheus` / `grafana` (versions light) ou `nginx` bien dimensionné | Requests = usage réel, charge stable | Sert de référence/baseline pour comparer l'efficacité des autres équipes |

### Pourquoi ces choix de workloads

- **Images ultra-légères** (quelques Mo, démarrage en secondes) : idéal sur un cluster local k3d, aucune dépendance externe à gérer.
- **Pas de vraie logique métier nécessaire** : Kubecost ne regarde pas ce que fait l'appli, seulement ce qu'elle consomme vs ce qu'elle demande. Mieux vaut des workloads "boîtes noires" contrôlables que du code applicatif réel à maintenir.
- **`k6`/`hey`** pour `team-catalog` : génère un vrai pic CPU mesurable, plus crédible qu'un scaling déclenché artificiellement sans charge réelle derrière.
- **PostgreSQL non utilisé** sur `team-search` : simple à déployer, génère un PVC facilement "oubliable" pour le scénario de ressources orphelines.

### Exemple de profil de ressources (team-checkout)

```yaml
resources:
  requests:
    cpu: "1"          # ce que l'équipe "réserve" → coût alloué dans Kubecost
    memory: "2Gi"
  limits:
    cpu: "1"
    memory: "2Gi"
```

C'est l'écart entre ces `requests` et l'usage réel mesuré (via `metrics-server`, que Kubecost consomme aussi) qui crée le signal visuel dans le dashboard.

---

## Scripts de simulation

Chaque script agit sur un namespace pour produire un comportement de coût spécifique, observable dans Kubecost après un délai de collecte (~5-15 min selon la config).

- **`simulate_overprovisioning.sh`** — déploie les pods `team-checkout` avec des `requests` très supérieures aux besoins réels.
- **`simulate_traffic_spike.sh`** — lance un Job `k6`/`hey` contre `team-catalog` et fait varier les replicas (`kubectl scale`) pour simuler un pic de charge suivi d'un retour au calme.
- **`simulate_orphan_resources.sh`** — crée des PVC détachés, des Services LoadBalancer sans pods associés, des Jobs terminés jamais nettoyés sur `team-search`.
- **`simulate_idle_waste.sh`** — déploie des workloads avec des replicas au repos permanent (aucune charge réelle mais ressources réservées 24/7).
- **`reset_scenario.sh`** — nettoie l'ensemble des namespaces pour rejouer le scénario depuis zéro (utile pour une démo live).

Chaque script écrit un log horodaté dans `scripts/logs/` pour pouvoir recouper précisément l'action avec ce qui apparaît dans le dashboard.

---

## Mise en place de Kubecost

- Installation via Helm sur le cluster k3d.
- Configuration d'un **pricing custom** dans `kubecost/cloud-pricing.yaml` (k3d ne fournissant aucune donnée de facturation réelle) pour simuler des coûts réalistes (prix par vCPU/heure, par Gi/heure, etc.).
- Activation de l'allocation par `namespace`, `label`, et `annotation` dans `values.yaml`.
- Dashboard exposé en local via `kubectl port-forward` pour la démo.

---

## Couche Chargeback (la partie la plus démonstrative)

- **`fetch_kubecost_api.py`** : interroge l'API Kubecost (`/model/allocation`) pour extraire les coûts par équipe sur une période donnée.
- **`generate_report.py`** : transforme ces données en rapport lisible par équipe (CSV + version HTML simple), avec :
  - coût total par équipe
  - répartition CPU / mémoire / stockage / réseau
  - écart entre coût alloué (requests) et coût réel (usage)
  - part des coûts partagés (control plane, monitoring, ingress) répartie au prorata de la consommation
- Objectif : simuler une **"facture interne"** telle qu'une équipe FinOps l'enverrait à chaque produit.

---

## Scénario de démonstration (pitch en 10 minutes)

1. **Avant** : montrer le dashboard Kubecost sur un cluster "propre", coûts globalement homogènes.
2. **Lancer les scripts de simulation** un par un, en expliquant le comportement injecté.
3. **Observer en direct** l'évolution du dashboard : `team-checkout` explose en coût "alloué" vs "utilisé", `team-search` fait apparaître des ressources orphelines, `team-catalog` montre un pic puis un retour à la normale.
4. **Générer le rapport de chargeback** et montrer comment ces données brutes deviennent une facture actionnable par équipe.
5. **Proposer le rightsizing** sur `team-checkout` et rejouer le scénario pour montrer l'économie réalisée.

---

## Roadmap

- [ ] Setup cluster k3d (`k3d cluster create kubecost-lab --agents 3 --servers 1`)
- [ ] Install Kubecost + pricing custom
- [ ] Déploiement des 4 namespaces + labels + workloads
- [ ] Scripts de simulation (un par comportement)
- [ ] Extraction API + génération de rapport
- [ ] Scénario de démo scripté et rejouable
- [ ] (Bonus) Dashboard Grafana branché sur l'API Kubecost pour une vue custom
- [ ] (Bonus) Alerting sur dérive budgétaire par équipe