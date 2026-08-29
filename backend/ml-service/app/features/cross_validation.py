from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List


def _parse_date(value):
    if not value:
        return None
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def cross_validate_gst_bank(gst_data: Dict[str, Any], bank_statement: Dict[str, Any], window_days: int = 45) -> Dict[str, Any]:
    invoices = gst_data.get("invoices", []) or []
    bank_transactions = bank_statement.get("transactions", []) or []

    invoice_amounts = []
    bank_credits = []
    matches = []

    for invoice in invoices:
        date = _parse_date(invoice.get("date"))
        amount = _safe_float(invoice.get("amount"), 0.0)
        if date and amount > 0:
            invoice_amounts.append((date, amount))

    for txn in bank_transactions:
        txn_type = str(txn.get("type", "")).lower()
        if txn_type == "credit":
            date = _parse_date(txn.get("date"))
            amount = _safe_float(txn.get("amount"), 0.0)
            if date and amount > 0:
                bank_credits.append((date, amount))

    for invoice_date, invoice_amount in invoice_amounts:
        match_amount = 0.0
        for bank_date, bank_amount in bank_credits:
            diff = abs((bank_date - invoice_date).days)
            if diff <= window_days:
                match_amount += bank_amount
        matches.append({
            "invoice_date": invoice_date.isoformat(),
            "invoice_amount": invoice_amount,
            "matched_bank_amount": round(match_amount, 2),
            "within_window_days": diff if 'diff' in locals() else window_days,
        })

    gst_total = sum(amount for _, amount in invoice_amounts)
    bank_total = sum(amount for _, amount in bank_credits)
    matched_total = sum(item["matched_bank_amount"] for item in matches)
    discrepancy_ratio = 0.0 if gst_total == 0 else (abs(gst_total - bank_total) / gst_total) * 100.0
    match_ratio = 0.0 if gst_total == 0 else (matched_total / gst_total) * 100.0

    return {
        "discrepancy_ratio": round(discrepancy_ratio, 2),
        "match_ratio": round(match_ratio, 2),
        "matched_total": round(matched_total, 2),
        "gst_total": round(gst_total, 2),
        "bank_total": round(bank_total, 2),
        "matches": matches,
        "window_days": window_days,
    }
