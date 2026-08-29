from __future__ import annotations

from typing import Any, Dict, List


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def compute_gst_features(gst_data: Dict[str, Any]) -> Dict[str, Any]:
    filings = gst_data.get("filings", []) or gst_data.get("months", []) or []
    if not filings:
        invoices = gst_data.get("invoices", []) or []
        if invoices:
            filings = [{"month": "2026-01", "turnover": sum(_safe_float(i.get("amount")) for i in invoices), "on_time": True}]
        else:
            return {
                "turnover_trend": 0.0,
                "filing_punctuality": 0.0,
                "revenue_diversification": 0.0,
                "receivables_efficiency": 0.0,
            }

    turnovers = [_safe_float(item.get("turnover"), 0.0) for item in filings]
    on_time_count = sum(1 for item in filings if bool(item.get("on_time")))
    punctuality = (on_time_count / max(1, len(filings))) * 100.0

    if len(turnovers) >= 2:
        first, last = turnovers[0], turnovers[-1]
        turnover_trend = ((last - first) / max(1.0, abs(first))) * 100.0
    else:
        turnover_trend = 0.0

    unique_counterparties = set()
    for item in filings:
        for counterparty in item.get("counterparties", []) or []:
            unique_counterparties.add(str(counterparty))
    revenue_diversification = max(len(unique_counterparties), 1)

    return {
        "turnover_trend": round(turnover_trend, 2),
        "filing_punctuality": round(punctuality, 2),
        "revenue_diversification": float(revenue_diversification),
        "receivables_efficiency": round(100.0 - max(0.0, abs(turnover_trend) * 0.3), 2),
        "months_seen": len(filings),
    }
