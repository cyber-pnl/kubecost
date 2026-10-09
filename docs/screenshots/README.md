# docs/screenshots/ — Captures pour la démo

Ce dossier accueille les captures d'écran « de secours » utilisées pendant la
démo (cf. [workflows.md](../agents/workflows.md)). La capture nécessite un
**navigateur** : elle est donc manuelle (aucune capture automatisée dans ce lab).

## Préparer les accès

```bash
# Ouvre les port-forwards Kubecost (9090) + Grafana (3000) et affiche la liste
./scripts/open_dashboards.sh
```

| Interface | URL | Identifiants |
|---|---|---|
| Kubecost | http://localhost:9090 | — |
| Grafana | http://localhost:3000 | `admin` / voir `secret grafana` |
| Rapport HTML | `chargeback/reports/chargeback-*.html` | — (fichier local) |

## Captures à réaliser

| Fichier attendu | Vue | Message à illustrer |
|---|---|---|
| `01-checkout-overprovisioning.png` | Kubecost → Allocation, `team-checkout` | requests 1 CPU/2Gi vs usage ~0 → gaspillage |
| `02-catalog-spike.png` | Kubecost → Allocations sur 6–24 h | coût variable (HPA 1→N) |
| `03-search-orphans.png` | Kubecost → Assets (PVC/LB) | coûts cachés non nettoyés |
| `04-grafana-teams.png` | Grafana « Kubecost — Coûts par equipe » | requests vs usage, coût par nœud |
| `05-chargeback-report.png` | `chargeback/reports/*.html` | rapport par équipe + réconciliation |
| `06-rightsizing-avant-apres.png` | avant/après `./scripts/rightsize_demo.sh` | -34 $/mois/réplica |

## Bonnes pratiques

- Nommer les fichiers `NN-sujet.png` (ordre de la démo).
- Conserver la fenêtre de temps visible (prouve la corrélation avec les logs
  de `scripts/logs/`).
- Masquer toute donnée sensible (aucune dans ce lab, mais par principe).
- Versionner les captures utiles ; éviter les images trop lourdes (> 1 Mo).
