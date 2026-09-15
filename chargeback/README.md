# chargeback/ — Extraction API & rapports

Couche de « facturation interne » : interroge l'API Kubecost et transforme les données de coût en rapports actionnables par équipe.

| Fichier (à créer — voir [roadmap](../docs/roadmap.md) Phase 5) | Rôle |
|---|---|
| `fetch_kubecost_api.py` | Interroge `/model/allocation` (fenêtre paramétrable) |
| `generate_report.py` | Génère rapport CSV + HTML par équipe |
| `reports/` | Rapports générés (gitignorés) |

## Format de rapport attendu

- Coût total par équipe
- Ventilation CPU / mémoire / stockage / réseau
- Écart coût **alloué** (requests) vs coût **utilisé** (usage réel)
- Part des coûts **partagés** répartie au prorata de la consommation
- Recommandations actionnables (rightsizing, nettoyage)

## Usage (une fois implémenté)

```bash
python chargeback/fetch_kubecost_api.py --window 24h
python chargeback/generate_report.py --format html
```

## Règles

- `reports/` ne contient AUCUN secret.
- Reconcilication : total alloué ≈ total cluster (< 5 %).
- Python PEP 8 + type hints.
- Détails : [docs/finops-practices.md](../docs/finops-practices.md).