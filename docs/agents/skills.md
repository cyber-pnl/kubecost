# Agent Skills — Kubecost FinOps Lab

Référence des **compétences requises** pour travailler sur chacune des parties du dépôt. Choisissez la skill adaptée à votre tâche avant d'agir.

## 1. Kubernetes Infrastructure (k3d)

- **Scope commit** : `cluster`
- **Responsabilités** : provisioning du cluster, gestion des nodes, configuration réseau
- **Fichiers concernés** : `cluster/k3d-config.yaml`, `cluster/setup-cluster.sh`

### Bonnes pratiques
- Créer le cluster avec `--agents 3 --servers 1` pour un multi-node réaliste
- Tirer parti du `servicelb` intégré (k3s) pour simuler des `Service` LoadBalancer
- Garder un cluster léger pour des cycles reset/replay rapides (démo)
- Figer les versions des images (node, tools) — pas de `latest` non suivi
- Vérifier l'état après provisionning : `kubectl get nodes -o wide`

### Compétences techniques
- `k3d` (config YAML, ports, réseaux, volumes)
- `kubectl` avancé (contexts, apply, top, logs, port-forward)
- Composants k3s : servicelb, traefik, metrics-server

---

## 2. Kubecost & Allocation de coûts

- **Scope commit** : `kubecost`
- **Responsabilités** : installation Kubecost (Helm), pricing custom, allocation, alerting
- **Fichiers concernés** : `kubecost/install-kubecost.sh`, `kubecost/values.yaml`, `kubecost/cloud-pricing.yaml`

### Bonnes pratiques
- Configurer un **pricing custom** pour k3d (aucune donnée de facturation réelle) : prix vCPU/h, Gi/h, stockage, réseau
- Allouer par `namespace`, `label` et `annotation` dans `values.yaml`
- Toujours définir la politique d'allocation des coûts **idle** et **partagés** (control plane, monitoring, ingress) — distribution proportionnelle à documenter
- Paramétrer une fenêtre d'allocation minimale de 15 min pour des données exploitables
- Mettre en place des alertes de dérive budgétaire par namespace

### Compétences techniques
- Helm (install, values, upgrade)
- API Kubecost (`/model/allocation`, `/model/assets`)
- Prometheus (scraping, retention, queries)

---

## 3. Workload Simulation (équipes)

- **Scope commit** : `teams`, `scripts`
- **Responsabilités** : déploiement des 4 namespaces, profils de ressources, scripts de simulation
- **Fichiers concernés** : `teams/*/namespace.yaml`, `teams/*/deployment.yaml`, `scripts/*.sh`

### Bonnes pratiques
- Images ultra-légères : `hashicorp/http-echo`, `nginx`, `postgres`, `k6`
- Charger les `requests`/`limits` de façon **intentionnelle** et **documentée** (commentaire dans le manifest)
- Labels obligatoires : `team`, `product`, `env` (+ labels FinOps recommandés par Kubecost)
- Chaque script de simulation écrit un **log horodaté** dans `scripts/logs/`
- `reset_scenario.sh` doit nettoyer l'intégralité des namespaces pour rejouer la démo

### Compétences techniques
- Kubernetes objects : Namespace, Deployment, Service, HPA, PVC, Job, ResourceQuota, LimitRange
- Scripting Bash robuste (`set -euo pipefail`)
- Génération de charge : `k6` / `hey`

---

## 4. Chargeback & Reporting

- **Scope commit** : `chargeback`
- **Responsabilités** : extraction API Kubecost, génération de rapports CSV/HTML, analyse
- **Fichiers concernés** : `chargeback/fetch_kubecost_api.py`, `chargeback/generate_report.py`, `chargeback/reports/`

### Bonnes pratiques
- Interroger `/model/allocation` avec une fenêtre de temps explicite et cohérente entre appels
- Ne générer des rapports qu'après **collecte suffisante** (≥ 1 h, idéalement 24 h)
- Rapports par équipe avec : coût total, ventilation CPU/mémoire/stockage/réseau, écart alloué vs utilisé
- Répartir les coûts **partagés** au prorata de la consommation (méthode documentée)
- Fournir des recommandations actionnables (rightsizing, nettoyage)

### Compétences techniques
- Python PEP 8 + type hints
- `requests` / HTTP API
- Pandas ou CSV stdlib pour l'agrégation
- Génération HTML simple (template)

---

## 5. FinOPS Governance

- **Scope commit** : `finops`
- **Responsabilités** : ResourceQuota, LimitRange, budgets, rightsizing, alerting
- **Fichiers concernés** : `teams/*/namespace.yaml`, `kubecost/values.yaml`, alertes

### Bonnes pratiques
- Enforce `requests`/`limits` à l'admission (LimitRange) — ne pas dépendre de la bonne volonté
- ResourceQuota par namespace pour éviter la « tragédie des communs »
- **Showback avant chargeback** : diffuser les coûts ~90 jours avant d'imputer un budget
- Utiliser les recommandations VPA (mode `Off`) pour le rightsizing
- Alerting sur écart budgétaire : seuil quotidien, dérive > 30 % hebdo sans changement de déploiement
- Coût CPU : requests à 50-70 % de l'usage moyen ; mémoire : ~90 % (OOM plus coûteux que throttling)

### Compétences techniques
- Kubernetes quota / admission control
- Kubecost savings & budgets
- Règles Prometheus / alerting