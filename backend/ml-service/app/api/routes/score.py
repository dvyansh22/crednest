from __future__ import annotations

from typing import Any, Dict, List, Optional

from fastapi import APIRouter
from pydantic import BaseModel, Field

from app.config import settings
from app.ensemble.score_aggregator import ScoreAggregator

router = APIRouter(prefix="/score", tags=["score"])


class QuizResponse(BaseModel):
    question_id: str
    answer: Any


class ScoreRequest(BaseModel):
    borrower_id: Optional[str] = None
    person_id: Optional[str] = None
    borrower_type: str = "individual"
    bank_statement: Dict[str, Any] = Field(default_factory=dict)
    gst_data: Optional[Dict[str, Any]] = None
    quiz_responses: List[QuizResponse] = Field(default_factory=list)
    location: Optional[Dict[str, float]] = None
    federated_delta: Optional[Dict[str, Any]] = None
    features: Dict[str, Any] = Field(default_factory=dict)
    geohash_stability: Optional[float] = None


class ScoreResponse(BaseModel):
    borrower_id: Optional[str] = None
    person_id: Optional[str] = None
    score_value: int
    risk_band: str
    max_eligible_amount: int
    confidence: float
    npa_probability: float
    npa_alert: Optional[str] = None
    explanation: str
    signal_contributions: List[Dict[str, Any]]
    is_mock: bool = False
    confidence_band: List[int]
    stress_profile: Dict[str, Any]


@router.post("", response_model=ScoreResponse)
async def score_borrower(payload: ScoreRequest):
    aggregator = ScoreAggregator()
    borrower_id = payload.borrower_id or payload.person_id or "unknown"
    quiz_dicts = [{"question_id": q.question_id, "answer": q.answer} for q in payload.quiz_responses]

    agg_result = aggregator.score(
        borrower_id=borrower_id,
        bank_statement=payload.bank_statement,
        gst_data=payload.gst_data,
        quiz_responses=quiz_dicts,
        federated_delta=payload.federated_delta
    )

    base_score = int(agg_result["credit_score"])
    
    geohash_bonus = 0
    if payload.geohash_stability is not None:
        geohash_bonus = int((payload.geohash_stability - 0.5) * 10)
        base_score = max(300, min(850, base_score + geohash_bonus))
    
    if base_score >= 750:
        risk_band = "P1"
    elif base_score >= 650:
        risk_band = "P2"
    elif base_score >= 550:
        risk_band = "P3"
    else:
        risk_band = "P4"

    max_amount = 100000 if base_score >= 720 else (50000 if base_score >= 580 else 25000)
    
    npa_probability = 0.65 if agg_result.get("npa_alert") else 0.05
    npa_alert = agg_result.get("npa_alert")
    
    if payload.geohash_stability is not None and payload.geohash_stability < 0.2:
        npa_alert = "Fraud Risk: Highly unstable geohash location."
        npa_probability = max(0.95, npa_probability)
        base_score = min(base_score, 400)
        risk_band = "P4"

    return {
        "borrower_id": borrower_id,
        "person_id": payload.person_id,
        "score_value": int(base_score),
        "risk_band": risk_band,
        "max_eligible_amount": max_amount,
        "confidence": 0.85,
        "npa_probability": npa_probability,
        "npa_alert": npa_alert,
        "explanation": agg_result.get("character_narrative", ""),
        "signal_contributions": agg_result.get("signal_contributions", []),
        "is_mock": False,
        "confidence_band": agg_result.get("confidence_band", [base_score - 35, base_score + 28]),
        "stress_profile": agg_result.get("stress_profile", {})
    }
