from __future__ import annotations

from typing import Any, Dict, List

from fastapi import APIRouter
from pydantic import BaseModel, Field

from app.features.bank_features import GIG_KEYWORDS

router = APIRouter(prefix="/narration", tags=["narration"])


class TransactionInput(BaseModel):
    date: str
    narration: str
    amount: float


class NarrationRequest(BaseModel):
    transactions: List[TransactionInput] = Field(..., min_length=1)


def _classify_single_transaction(item: TransactionInput) -> Dict[str, Any]:
    text = (item.narration or "").lower()
    source = "Other Income"
    for keyword, mapped_source in GIG_KEYWORDS.items():
        if keyword in text:
            source = mapped_source
            break
    if source == "Other Income" and any(term in text for term in ["upi", "neft", "imps", "p2p"]):
        source = "Platform Income"

    return {
        "date": item.date,
        "source": source,
        "category": "gig_income" if source != "Other Income" else "misc_income",
        "amount": float(item.amount),
    }


@router.post("/classify")
def classify_narration(payload: NarrationRequest):
    classified = [_classify_single_transaction(item) for item in payload.transactions]
    total = sum(item["amount"] for item in classified)
    sources = sorted({item["source"] for item in classified if item["source"] != "Other Income"})
    return {
        "classified": classified,
        "monthly_gig_income_summary": {
            "total": round(total, 2),
            "sources": sources,
        },
    }
