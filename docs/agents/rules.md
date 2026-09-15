# Agent Rules — Règles détaillées par domaine

Règles à respecter impérativement. S'appuient sur les conventions générales d'[AGENTS.md](../../AGENTS.md) et les bonnes pratiques issues du terrain (FinOps Foundation, CNCF, blogs SRE 2026).

## Domaines

- [Cluster (k3d)](#cluster-k3d)
- [Kubecost & pricing](#kubecost--pricing)
- [Équipes simulées](#équipes-simulées)
- [Scripts de simulation](#scripts-de-simulation)
- [Chargeback](#chargeback)
- [Documentation](#documentation)
- [Qualité & validation](#qualité--validation)

---

## Cluster (k3d)

1. Ne jamais exposer le cluster ou le dashboard à un réseau public sans validation explicite.
2. Accès Kubecost **uniquement** via `kubectl port-forward`.
3. Toute modification de `cluster/k3d-config.yaml` DOIT être reflétée dans `cluster/setup-cluster.sh` et documentée dans le message de commit.
4. Privilégier des nodes modérées (2-4 vCPU) et suffisamment nombreuses pour qu'une panne node < 10 % de capacité totale.
5. Avant toute démo : `./scripts/reset_scenario.sh` puis vérification `kubectl get nodes`.
6. Backup / état reproductible : le cluster doit pouvoir être recréé à l'identique depuis `k3d-config.yaml`.

### Guardrails réseau & sécurité
- RBAC privilège minimum pour les service accounts.
- NetworkPolicy par défaut (deny-all) sur les namespaces teams si déployé.
- Pas de secret dans les manifests.

---

## Kubecost & pricing

1. Toujours configurer un **pricing custom** pour k3d (`cloud-pricing.yaml`) : paires `vCPU/heure`, `Gi/heure`, `Gi heure de stockage`, coût réseau.
2. Activer l'allocation par `namespace`, `label` et `annotation`.
3. Documenter explicitement la politique d'allocation des coûts **idle** et **partagés** (control plane, monitoring). Répartition proportionnelle par défaut.
4. Fenêtre d'allocation minimum `15m` ; les rapports chargeback n'utilisent pas moins de `1h`.
5. Tester la formule de pricing avant publication : un écart incohérent en `indexingDuration` ou `cpuCoreUsageAverage` doit être investigué avant d'attribuer un coût.
6. Le port-forward par défaut : `kubectl port-forward svc/kubecost-cost-analyzer -n kubecost 9090:9090`.

---

## Équipes simulées

1. Chaque ressources DOIT porter les labels `team`, `product`, `env`.
2. Chaque conteneur DOIT avoir `requests` ET `limits` (cpu + memory).
3. Le sur-dimensionnement intentionnel DOIT être commenté : `# over-provisioning intent: 90% waste for demo`.
4. Un namespace d'équipe contient `namespace.yaml`, `deployment.yaml`, `behavior.md`.
   - `namespace.yaml` : ResourceQuota + LimitRange + labels.
   - `behavior.md` : comportement simulé, signal Kubecost attendu, scénario lié.
5. Profils attendus :
   - `team-checkout` : requests hautes (ex 1 CPU / 2Gi) pour usage minime.
   - `team-catalog` : requests raisonnables + HPA (1→10) + générateur de charge.
   - `team-search` : PVC détaché, LoadBalancer sans backend, Jobs terminés non nettoyés.
   - `team-platform` : requests = usage, baseline (référence à 100 % d'efficience).
6. Ne jamais laisser tourner inutilement les workloads de simulation après une démo (reset).

---

## Scripts de simulation

1. Tous les scripts Bash : `set -euo pipefail`.
2. Chaque script écrit un log **horodaté** dans `scripts/logs/` pour corréler action ↔ dashboard.
3. `reset_scenario.sh` nettoie : namespaces teams, PVC, LoadBalancers, Jobs, HPA.
4. Ne pas écrire en dur de chemins absolus ; utiliser le chemin relatif depuis la racine du repo.
5. Les scripts doivent être **rejouables** (idempotence : `kubectl apply --dry-run=client` ou delete+create).

---

## Chargeback

1. Générer les rapports uniquement avec une fenêtre d'au moins 1 h de données.
2. Documenter la méthode d'allocation (direct + partagé + idle) dans le rapport.
3. Inclure au minimum : coût total par équipe, répartition CPU/mémoire/stockage/réseau, écart alloué vs utilisé, part des coûts partagés.
4. Sorties : CSV (+ HTML simple) par équipe dans `chargeback/reports/`.
5. Reconcilier le total alloué avec le total du cluster (l'écart doit être < 5 %, sinon bug d'allocation).
6. Python : PEP 8, type hints, pas de secret.

---

## Documentation

1. Tout diagramme en **Mermaid** (architecture, flow, séquence).
2. `README.md` = overview haut niveau uniquement, renvoie vers `docs/`.
3. Les recommandations FinOPS et les choix d'allocation DOIVENT être documentés (reproductibilité).
4. Les screenshots du dashboard vont dans `docs/screenshots/`.
5. Convention de commits de type `docs` pour toute modification documentaire.

---

## Qualité & validation

- YAML : `yamllint`
- Bash : `shellcheck`
- Python : `ruff` / PEP 8 + mypy si applicable
- Validations exécutées avant de clôturer une tâche (voir [workflows.md](workflows.md)).