#!/usr/bin/env python3
"""Génère un rapport de chargeback (CSV + HTML) depuis l'allocation Kubecost.

Lit un JSON produit par fetch_kubecost_api.py, ou interroge directement l'API.
Sortie : chargeback/reports/chargeback_<horodatage>.{csv,html}

PEP 8 + type hints, stdlib uniquement.
"""
from __future__ import annotations

import argparse
import csv
import json
from datetime import datetime
from pathlib import Path

from fetch_kubecost_api import fetch_allocation


class Entry:
    """Vue normalisée d'une ligne d'allocation Kubecost."""

    def __init__(self, name: str, raw: dict) -> None:
        self.name = name
        self.raw = raw
        self.labels: dict[str, str] = (raw.get("properties") or {}).get("labels") or {}
        self.total_cost = float(raw.get("totalCost") or 0)
        self.cpu_cost = float(raw.get("cpuCost") or 0)
        self.ram_cost = float(raw.get("ramCost") or 0)
        self.storage_cost = float(raw.get("pvCost") or 0)
        self.network_cost = float(raw.get("networkCost") or 0)
        self.lb_cost = float(raw.get("loadBalancerCost") or 0)
        self.shared_cost = float(raw.get("sharedCost") or 0)
        self.cpu_req = float(raw.get("cpuCoreRequestAverage") or 0)
        self.cpu_used = float(raw.get("cpuCoreUsageAverage") or 0)
        self.cpu_hours = float(raw.get("cpuCoreHours") or 0)
        self.cpu_eff = float(raw.get("cpuEfficiency") or 0)
        self.ram_eff = float(raw.get("ramEfficiency") or 0)
        self.total_eff = float(raw.get("totalEfficiency") or 0)

    @property
    def is_special(self) -> bool:
        return self.name.startswith("__")

    @property
    def used_cost_est(self) -> float:
        """Coût « utilisé » estimé (usage réel) vs coût alloué (requests)."""
        return (
            self.cpu_cost * self.cpu_eff
            + self.ram_cost * self.ram_eff
            + self.storage_cost
            + self.network_cost
            + self.lb_cost
        )

    @property
    def allocated_gap(self) -> float:
        return self.total_cost - self.used_cost_est

    def recommendation(self) -> str:
        if self.total_cost <= 0:
            return ""
        if self.name == "__idle__":
            return "Capacité réservée non consommée : right-sizing des nœuds ou consolidation."
        if self.name == "__unallocated__" and (self.storage_cost > 0 or self.cpu_cost > 0):
            return "Ressources orphelines (PVC non monté, LB sans backend, Job terminé)."
        if self.cpu_cost > 0.01 and self.cpu_eff < 0.10:
            return f"CPU sur-dimensionné (efficacité {self.cpu_eff:.1%}) : réduire les requests."
        if self.ram_cost > 0.01 and self.ram_eff < 0.10:
            return f"RAM sur-dimensionnée (efficacité {self.ram_eff:.1%}) : réduire les requests."
        if self.storage_cost > 0 and self.total_eff < 0.5:
            return "Stockage sous-utilisé."
        return "Dimensionnement cohérent avec l'usage."


def _last_set(payload: dict) -> dict:
    sets = [s for s in (payload.get("data") or []) if s]
    return sets[-1] if sets else {}


def _total_of(entries: dict) -> float:
    return sum(float((raw or {}).get("totalCost") or 0) for raw in entries.values())


def build_entries(entries: dict) -> list[Entry]:
    rows = [Entry(name, raw) for name, raw in entries.items() if raw]
    rows.sort(key=lambda e: (e.is_special, -e.total_cost))
    return rows


def _fmt(value: float) -> str:
    return f"{value:,.4f}"


def write_csv(path: Path, rows: list[Entry], meta: dict, allocated_total: float) -> None:
    sums = {
        "cpu_cost": sum(e.cpu_cost for e in rows),
        "ram_cost": sum(e.ram_cost for e in rows),
        "storage_cost": sum(e.storage_cost for e in rows),
        "network_cost": sum(e.network_cost for e in rows),
        "lb_cost": sum(e.lb_cost for e in rows),
        "shared_cost": sum(e.shared_cost for e in rows),
        "cpu_req_avg": sum(e.cpu_req for e in rows),
        "cpu_used_avg": sum(e.cpu_used for e in rows),
        "cpu_core_hours": sum(e.cpu_hours for e in rows),
        "used_cost_est": sum(e.used_cost_est for e in rows),
        "allocated_gap": sum(e.allocated_gap for e in rows),
    }
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow([f"# window={meta.get('window')} aggregate={meta.get('aggregate')} "
                         f"share_idle={meta.get('share_idle')} fetched_at={meta.get('fetched_at')}"])
        writer.writerow(COLUMNS)
        for entry in rows:
            writer.writerow([
                entry.name,
                _fmt(entry.total_cost),
                _fmt(entry.cpu_cost),
                _fmt(entry.ram_cost),
                _fmt(entry.storage_cost),
                _fmt(entry.network_cost),
                _fmt(entry.lb_cost),
                _fmt(entry.shared_cost),
                _fmt(entry.cpu_req),
                _fmt(entry.cpu_used),
                _fmt(entry.cpu_hours),
                f"{entry.cpu_eff:.4f}",
                f"{entry.total_eff:.4f}",
                _fmt(entry.used_cost_est),
                _fmt(entry.allocated_gap),
                entry.recommendation(),
            ])
        writer.writerow([
            "TOTAL",
            _fmt(allocated_total), _fmt(sums["cpu_cost"]), _fmt(sums["ram_cost"]),
            _fmt(sums["storage_cost"]), _fmt(sums["network_cost"]), _fmt(sums["lb_cost"]),
            _fmt(sums["shared_cost"]), _fmt(sums["cpu_req_avg"]), _fmt(sums["cpu_used_avg"]),
            _fmt(sums["cpu_core_hours"]), "", "", _fmt(sums["used_cost_est"]),
            _fmt(sums["allocated_gap"]), "",
        ])


def write_html(path: Path, rows: list[Entry], meta: dict,
               cluster_total: float, allocated_total: float, recon_pct: float) -> None:
    teams = [e for e in rows if not e.is_special]
    specials = [e for e in rows if e.is_special]
    max_cost = max([e.total_cost for e in rows] + [0.0001])
    rows_teams = "".join(_bar_row(e, max_cost) for e in teams)
    rows_special = "".join(_bar_row(e, max_cost, muted=True) for e in specials)
    table = "".join(_table_row(e) for e in rows)
    html_doc = _HTML_TEMPLATE.format(
        window=meta.get("window", ""),
        aggregate=meta.get("aggregate", ""),
        share_idle=meta.get("share_idle", False),
        fetched_at=meta.get("fetched_at", ""),
        n_teams=len(teams),
        total=_fmt(allocated_total),
        cluster=_fmt(cluster_total),
        recon=_fmt(cluster_total - allocated_total),
        recon_pct=f"{recon_pct:.2f}",
        team_bars=rows_teams,
        special_bars=rows_special,
        table=table,
    )
    path.write_text(html_doc, encoding="utf-8")


def _bar_row(entry: Entry, max_cost: float, muted: bool = False) -> str:
    pct = (entry.total_cost / max_cost * 100) if max_cost else 0
    css = "bar muted" if muted else "bar"
    return (
        f'<div class="barrow"><span class="barlabel">{entry.name}</span>'
        f'<span class="{css}" style="width:{pct:.2f}%">{_fmt(entry.total_cost)} $</span></div>'
    )


def _table_row(entry: Entry) -> str:
    return (
        "<tr>"
        f"<td>{entry.name}</td>"
        f"<td class='num'>{_fmt(entry.total_cost)}</td>"
        f"<td class='num'>{_fmt(entry.cpu_cost)}</td>"
        f"<td class='num'>{_fmt(entry.ram_cost)}</td>"
        f"<td class='num'>{_fmt(entry.storage_cost)}</td>"
        f"<td class='num'>{_fmt(entry.network_cost)}</td>"
        f"<td class='num'>{_fmt(entry.lb_cost)}</td>"
        f"<td class='num'>{_fmt(entry.used_cost_est)}</td>"
        f"<td class='num'>{_fmt(entry.allocated_gap)}</td>"
        f"<td class='num'>{entry.total_eff:.1%}</td>"
        f"<td class='rec'>{entry.recommendation()}</td>"
        "</tr>"
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Rapport de chargeback Kubecost (CSV + HTML).")
    parser.add_argument("--url", default="http://localhost:9090", help="URL Kubecost")
    parser.add_argument("--window", default="1d", help="1d, 24h, 7d...")
    parser.add_argument("--aggregate", default="label:team", help="label:team, namespace...")
    parser.add_argument("--share-idle", action="store_true", help="répartir l'idle sur les équipes")
    parser.add_argument("--allocation", type=Path, help="JSON d'allocation déjà extrait")
    parser.add_argument("--out-dir", type=Path, default=Path(__file__).resolve().parent / "reports")
    args = parser.parse_args(argv)

    from fetch_kubecost_api import fetch_allocation

    if args.allocation:
        raw = json.loads(args.allocation.read_text(encoding="utf-8"))
    else:
        raw = fetch_allocation(args.url, args.window, args.aggregate, share_idle=args.share_idle)

    meta = raw.get("_meta") or {"window": args.window, "aggregate": args.aggregate,
                                "share_idle": args.share_idle, "fetched_at": ""}
    entries = _last_set(raw)
    cluster_raw = fetch_allocation(args.url, args.window, "cluster")
    cluster_entries = _last_set(cluster_raw)
    cluster_total = _total_of(cluster_entries)
    allocated_total = _total_of(entries)
    diff = cluster_total - allocated_total
    pct = (abs(diff) / cluster_total * 100) if cluster_total else 0.0

    rows = build_entries(entries)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    suffix = "-shared" if args.share_idle else ""
    csv_path = args.out_dir / f"chargeback-{stamp}{suffix}.csv"
    html_path = args.out_dir / f"chargeback-{stamp}{suffix}.html"
    write_csv(csv_path, rows, meta, allocated_total)
    write_html(html_path, rows, meta, cluster_total, allocated_total, pct)

    status = "OK" if pct < 5 else "ÉCART > 5%"
    print(f"[{status}] réconciliation : alloué={allocated_total:.4f} "
          f"cluster={cluster_total:.4f} écart={pct:.2f}%")
    print(f"[OK] {csv_path}")
    print(f"[OK] {html_path}")
    return 0


COLUMNS = [
    "name", "total_cost", "cpu_cost", "ram_cost", "storage_cost", "network_cost",
    "lb_cost", "shared_cost", "cpu_req_avg", "cpu_used_avg", "cpu_core_hours",
    "cpu_efficiency", "total_efficiency", "used_cost_est", "allocated_gap", "recommendation",
]


_HTML_TEMPLATE = """<!doctype html>
<html lang="fr"><head><meta charset="utf-8">
<title>Rapport chargeback Kubecost</title>
<style>
 body{{font-family:system-ui,Segoe UI,Roboto,sans-serif;margin:2rem;color:#1f2933}}
 h1{{font-size:1.5rem}} .meta{{color:#52606d;font-size:.9rem;margin-bottom:1.5rem}}
 .card{{background:#f5f7fa;border:1px solid #e4e7eb;border-radius:8px;padding:1rem 1.25rem;margin-bottom:1.25rem}}
 .barrow{{display:flex;align-items:center;gap:.75rem;margin:.35rem 0}}
 .barlabel{{width:14rem;font-size:.85rem;color:#3e4c59}}
 .bar{{display:inline-block;background:#486581;color:#fff;border-radius:4px;padding:.2rem .5rem;
       white-space:nowrap;min-width:4rem;font-size:.8rem}}
 .bar.muted{{background:#9aa5b1}}
 table{{border-collapse:collapse;width:100%;font-size:.82rem}}
 th,td{{border:1px solid #e4e7eb;padding:.4rem .5rem;text-align:left;vertical-align:top}}
 th{{background:#e4e7eb}} .num{{text-align:right;font-variant-numeric:tabular-nums}}
 .rec{{color:#3e4c59}} .ok{{color:#0b7285}} .warn{{color:#c92a2a}}
</style></head><body>
<h1>Rapport de chargeback — Kubecost</h1>
<div class="meta">Fenêtre <b>{window}</b> · agrégat <b>{aggregate}</b> ·
 partage idle <b>{share_idle}</b> · extrait le {fetched_at} · {n_teams} équipes</div>

<div class="card"><h2>Coût total par équipe</h2>{team_bars}
 <h3>Coûts non alloués</h3>{special_bars}</div>

<div class="card"><h2>Ventilation</h2>
<table><thead><tr>
<th>Élément</th><th>Total</th><th>CPU</th><th>RAM</th><th>Stockage</th><th>Réseau</th>
<th>LB</th><th>Utilisé (est.)</th><th>Alloué − utilisé</th><th>Efficacité</th><th>Recommandation</th>
</tr></thead><tbody>{table}</tbody></table></div>

<div class="card"><h2>Réconciliation</h2>
<p>Total alloué (toutes lignes) : <b>{total} $</b><br>
Total cluster : <b>{cluster} $</b> · écart <b>{recon} $</b>
<span class="warn">({recon_pct}% — cible &lt; 5%)</span></div>
</body></html>"""


if __name__ == "__main__":
    raise SystemExit(main())
