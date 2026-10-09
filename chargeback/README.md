# chargeback/ — Extraction API & rapports

Couche de « facturation interne » : interroge l'API Kubecost et transforme les données de coût en rapports actionnables par équipe.

| Fichier | Rôle |
|---|---|
| `fetch_kubecost_api.py` | Interroge `/model/allocation` (fenêtre/agrégat paramétrables) → JSON |
| `generate_report.py` | Génère rapport CSV + HTML par équipe (+ recommandations) |
| `reports/` | Rapports générés (gitignorés) |

## Format de rapport

Chaque rapport contient : coût **total par équipe**, ventilation **CPU / RAM /
stockage / réseau / LoadBalancer**, écart **alloué (requests) vs utilisé (usage
réel)**, lignes `__idle__` / `__unallocated__`, et des **recommandations**
(rightsizing, nettoyage d'orphelins).

## Usage

```bash
# 1) Port-forward vers l'API Kubecost
kubectl -n kubecost port-forward svc/kubecost-cost-analyzer 9090:9090 &

# 2a. Extraction brute (optionnelle)
python3 chargeback/fetch_kubecost_api.py --window 1d --aggregate label:team \
        --out chargeback/reports/allocation.json

# 2b. Rapport direct (allocation par équipe)
python3 chargeback/generate_report.py --window 1d

# Variante « chargeback » : l'idle est réparti sur les équipes au prorata
python3 chargeback/generate_report.py --window 1d --share-idle
```

Sorties : `chargeback/reports/chargeback-<horodatage>[-shared].{csv,html}`.

## Méthode d'allocation (documentée)

1. **Coûts directs** : `cpuCost` / `ramCost` / `pvCost` / `networkCost` /
   `loadBalancerCost` par équipe (label `team`).
2. **Coût alloué vs utilisé** : Kubecost alloue sur `max(requests, usage)`.
   L'efficacité (`cpuEfficiency`, `ramEfficiency`) permet d'estimer le coût
   réellement *utilisé* et l'écart = gaspillage potentiel.
3. **Coûts idle / non alloués** : exposés via `__idle__` (capacité nœuds non
   consommée) et `__unallocated__` (PVC non montés, LB sans backend, Jobs
   terminés). `--share-idle` les répartit au prorata.
4. **Réconciliation** : Σ(alloué) comparé au total cluster (`aggregate=cluster`),
   écart accepté < 5 % (mesuré : **0 %**).

## Règles

- `reports/` ne contient AUCUN secret et est gitignoré.
- Python PEP 8 + type hints, stdlib uniquement (aucune dépendance).
- Détails : [docs/finops-practices.md](../docs/finops-practices.md).