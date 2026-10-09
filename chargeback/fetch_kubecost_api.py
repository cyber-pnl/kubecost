#!/usr/bin/env python3
"""Interroge l'API Kubecost /model/allocation et enregistre le JSON brut.

PEP 8 + type hints, uniquement la bibliothèque standard.

Exemples :
    python3 chargeback/fetch_kubecost_api.py --window 1d --out reports/alloc.json
    python3 chargeback/fetch_kubecost_api.py --aggregate cluster --out reports/cluster.json
    python3 chargeback/fetch_kubecost_api.py --share-idle --out reports/shared.json
"""
from __future__ import annotations

import argparse
import json
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

DEFAULT_URL = "http://localhost:9090"
DEFAULT_WINDOW = "1d"
DEFAULT_AGGREGATE = "label:team"


def http_json(url: str, params: dict[str, str], timeout: float = 60.0) -> dict[str, Any]:
    """Effectue un GET JSON et renvoie le corps désérialisé."""
    query = urllib.parse.urlencode(params)
    full = f"{url.rstrip('/')}/model/allocation?{query}"
    request = urllib.request.Request(full, headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError) as exc:
        raise SystemExit(
            f"[ERREUR] API Kubecost injoignable : {full}\n  {exc}\n"
            "  Port-forward : kubectl -n kubecost port-forward "
            "svc/kubecost-cost-analyzer 9090:9090"
        ) from exc


def fetch_allocation(
    url: str = DEFAULT_URL,
    window: str = DEFAULT_WINDOW,
    aggregate: str = DEFAULT_AGGREGATE,
    *,
    share_idle: bool = False,
    include_idle: bool = True,
) -> dict[str, Any]:
    """Interroge /model/allocation et annote la réponse avec `_meta`."""
    params: dict[str, str] = {
        "window": window,
        "aggregate": aggregate,
        "accumulate": "true",
    }
    if share_idle:
        params["shareIdle"] = "true"
    if include_idle:
        params["idle"] = "true"

    payload = http_json(url, params)
    payload["_meta"] = {
        "url": url,
        "window": window,
        "aggregate": aggregate,
        "share_idle": share_idle,
        "include_idle": include_idle,
        "fetched_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    }
    return payload


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Extrait l'allocation de coûts Kubecost (/model/allocation)."
    )
    parser.add_argument("--url", default=DEFAULT_URL, help="URL de base Kubecost")
    parser.add_argument("--window", default=DEFAULT_WINDOW, help="1d, 24h, 7d...")
    parser.add_argument(
        "--aggregate", default=DEFAULT_AGGREGATE, help="label:team, namespace, cluster..."
    )
    parser.add_argument(
        "--share-idle", action="store_true", help="répartir l'idle sur les équipes"
    )
    parser.add_argument(
        "--no-idle", action="store_true", help="exclure __idle__/__unallocated__"
    )
    parser.add_argument("--out", type=Path, help="JSON de sortie (défaut : stdout)")
    args = parser.parse_args(argv)

    payload = fetch_allocation(
        args.url,
        args.window,
        args.aggregate,
        share_idle=args.share_idle,
        include_idle=not args.no_idle,
    )
    text = json.dumps(payload, indent=2, ensure_ascii=False)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text + "\n", encoding="utf-8")
        print(f"[OK] allocation écrite dans {args.out}")
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
