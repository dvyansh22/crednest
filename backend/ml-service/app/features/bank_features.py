from __future__ import annotations

from collections import defaultdict
from datetime import datetime
import math
from typing import Any, Dict, List


GIG_KEYWORDS = {
    "swiggy": "Swiggy",
    "ola": "Ola",
    "uber": "Uber",
    "zomato": "Zomato",
    "amazon seller": "Amazon Seller Services",
    "google": "Google AsiaPacific",
    "bharatpe": "BharatPe",
    "urbancompany": "Urban Company",
    "blinkit": "Blinkit",
}


def _parse_date(value):
    if not value:
        return None
    if isinstance(value, datetime):
        return value
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _match_gig_source(narration: str) -> str:
    text = (narration or "").lower()
    for keyword, source in GIG_KEYWORDS.items():
        if keyword in text:
            return source
    if any(token in text for token in ["upi", "neft", "imps", "p2p"]):
        return "Platform Income"
    return "Other Income"


def compute_bank_features(bank_statement: Dict[str, Any]) -> Dict[str, Any]:
    transactions = bank_statement.get("transactions", []) or []
    amounts = []
    credits = []
    debits = []
    gig_income = 0.0
    cash_withdrawals = 0.0
    upi_debits = 0.0
    income_dates = []

    for txn in transactions:
        amount = _safe_float(txn.get("amount"), 0.0)
        if amount == 0:
            continue
        amounts.append(amount)

        txn_type = str(txn.get("type", "")).lower()
        date = _parse_date(txn.get("date"))

        if txn_type == "credit":
            credits.append(amount)
            if date:
                income_dates.append(date)
            source = _match_gig_source(str(txn.get("narration", "")))
            if source != "Other Income":
                gig_income += abs(amount)
        elif txn_type == "debit":
            debits.append(amount)
            narration = str(txn.get("narration", "")).lower()
            if "atm" in narration or "withdraw" in narration:
                cash_withdrawals += abs(amount)
            if "upi" in narration or "qr" in narration:
                upi_debits += abs(amount)

    avg_monthly_inflow = sum(credits) / max(1, len(credits)) if credits else 0.0
    avg_monthly_outflow = sum(debits) / max(1, len(debits)) if debits else 0.0
    monthly_inflow = sum(credits) if credits else 0.0
    monthly_outflow = sum(debits) if debits else 0.0

    if len(income_dates) >= 2:
        intervals = []
        prev = income_dates[0]
        for current in income_dates[1:]:
            delta_days = (current - prev).days
            if delta_days > 0:
                intervals.append(delta_days)
            prev = current
        mean_interval = sum(intervals) / max(1, len(intervals)) if intervals else 30.0
        variance = sum((x - mean_interval) ** 2 for x in intervals) / max(1, len(intervals)) if intervals else 0.0
        regularity = 100.0 / (1.0 + math.sqrt(variance) / max(1.0, mean_interval))
    else:
        regularity = 50.0

    emi_like = 0.0
    for txn in transactions:
        narration = str(txn.get("narration", "")).lower()
        if "emi" in narration or "loan" in narration or "installment" in narration:
            emi_like += abs(_safe_float(txn.get("amount"), 0.0))

    total_outflow = sum(debits)
    upi_cash_ratio = (upi_debits / max(1.0, cash_withdrawals + upi_debits)) if (cash_withdrawals + upi_debits) > 0 else 0.0

    return {
        "cash_flow_velocity": (monthly_inflow / max(1.0, monthly_outflow)) if monthly_outflow else 1.0,
        "monthly_inflow": monthly_inflow,
        "monthly_outflow": monthly_outflow,
        "avg_monthly_inflow": avg_monthly_inflow,
        "avg_monthly_outflow": avg_monthly_outflow,
        "income_regularity_score": round(regularity, 2),
        "gig_income": round(gig_income, 2),
        "emi_like_debits": round(emi_like, 2),
        "upi_cash_ratio": round(upi_cash_ratio, 2),
        "transaction_count": len(transactions),
        "credit_to_debit_ratio": (sum(credits) / max(1.0, total_outflow)) if total_outflow else 1.0,
    }
