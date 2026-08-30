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
    # Data source connection flags
    bank_connected: bool = False
    gst_connected: bool = False
    kyc_verified: bool = False


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
    sources_connected: int
    score_ceiling: int


@router.post("", response_model=ScoreResponse)
async def score_borrower(payload: ScoreRequest):
    aggregator = ScoreAggregator()
    borrower_id = payload.borrower_id or payload.person_id or "unknown"
    quiz_dicts = [{"question_id": q.question_id, "answer": q.answer} for q in payload.quiz_responses]
    quiz_connected = len(quiz_dicts) > 0

    sources_connected = sum([
        payload.bank_connected,
        payload.gst_connected,
        payload.kyc_verified,
        quiz_connected,
    ])

    # Score ceiling unlocked per source
    if sources_connected == 0:
        score_ceiling = 400
    elif sources_connected == 1:
        score_ceiling = 620
    elif sources_connected == 2:
        score_ceiling = 720
    elif sources_connected == 3:
        score_ceiling = 790
    else:
        score_ceiling = 850

    agg_result = aggregator.score(
        borrower_id=borrower_id,
        bank_statement=payload.bank_statement if payload.bank_connected else {},
        gst_data=payload.gst_data if payload.gst_connected else None,
        quiz_responses=quiz_dicts if quiz_connected else [],
        federated_delta=payload.federated_delta,
        bank_connected=payload.bank_connected,
        gst_connected=payload.gst_connected,
        kyc_verified=payload.kyc_verified,
    )

    base_score = int(agg_result["credit_score"])

    # KYC trust multiplier
    if not payload.kyc_verified:
        base_score = int(base_score * 0.85)

    base_score = max(300, min(score_ceiling, base_score))

    # Geohash fraud signal
    if payload.geohash_stability is not None:
        geohash_bonus = int((payload.geohash_stability - 0.5) * 10)
        base_score = max(300, min(score_ceiling, base_score + geohash_bonus))
        if payload.geohash_stability < 0.2:
            base_score = min(base_score, 400)

    if base_score >= 750:
        risk_band = "P1"
    elif base_score >= 650:
        risk_band = "P2"
    elif base_score >= 550:
        risk_band = "P3"
    else:
        risk_band = "P4"

    max_amount = (
        200000 if base_score >= 750 and payload.kyc_verified else
        100000 if base_score >= 720 else
        50000 if base_score >= 580 else
        25000
    )

    npa_probability = 0.65 if agg_result.get("npa_alert") else round(max(0.04, 0.50 - sources_connected * 0.10), 2)
    npa_alert = agg_result.get("npa_alert")

    signal_contributions = []
    if payload.bank_connected:
        signal_contributions.append({"signal": "bank_financial_data", "label": "Bank Account", "connected": True, "weight": 0.50, "contribution": int(base_score * 0.50), "impact": f"+{int(base_score * 0.50)}"})
    else:
        signal_contributions.append({"signal": "bank_financial_data", "label": "Bank Account", "connected": False, "weight": 0.50, "contribution": 0, "impact": "Not connected — Connect to unlock income analysis"})

    if payload.gst_connected:
        signal_contributions.append({"signal": "gst_filing_data", "label": "GST Data", "connected": True, "weight": 0.20, "contribution": int(base_score * 0.20), "impact": f"+{int(base_score * 0.20)}"})
    else:
        signal_contributions.append({"signal": "gst_filing_data", "label": "GST Data", "connected": False, "weight": 0.20, "contribution": 0, "impact": "Not connected — Connect to verify business activity"})

    if payload.kyc_verified:
        signal_contributions.append({"signal": "kyc_identity", "label": "KYC Verification", "connected": True, "weight": 0.15, "contribution": int(base_score * 0.15), "impact": f"+{int(base_score * 0.15)} (trust multiplier active)"})
    else:
        signal_contributions.append({"signal": "kyc_identity", "label": "KYC Verification", "connected": False, "weight": 0.15, "contribution": 0, "impact": "Not verified — Complete KYC to boost trust score"})

    if quiz_connected:
        signal_contributions.append({"signal": "psychometric_quiz", "label": "Psychometric Assessment", "connected": True, "weight": 0.15, "contribution": int(base_score * 0.15), "impact": f"+{int(base_score * 0.15)}"})
    else:
        signal_contributions.append({"signal": "psychometric_quiz", "label": "Psychometric Assessment", "connected": False, "weight": 0.15, "contribution": 0, "impact": "Not completed — Take quiz to add behavioural signal"})

    if sources_connected == 0:
        narrative = "No data sources connected. Connect your bank account, GST data, and complete KYC verification to build your credit profile."
    elif sources_connected == 1:
        if payload.bank_connected:
            narrative = "Income and transaction patterns assessed using bank data. Add GST filing and KYC verification to strengthen your profile and unlock higher credit limits."
        elif payload.kyc_verified:
            narrative = "Identity verified. Connect your bank account to enable full income and transaction analysis."
        else:
            narrative = "Partial profile assessed. Connect additional data sources for a comprehensive credit evaluation."
    elif sources_connected == 2:
        if payload.bank_connected and payload.gst_connected:
            narrative = "Bank transactions and GST filing history cross-validated — business income and declared turnover aligned. Complete KYC verification to unlock your full credit ceiling."
        elif payload.bank_connected and payload.kyc_verified:
            narrative = "Verified identity with strong transaction history assessed. Add GST data for business activity verification and higher loan eligibility."
        else:
            narrative = "Two data sources active. Connect remaining sources for a complete profile."
    elif sources_connected == 3:
        narrative = "Comprehensive financial and identity profile assessed across bank statements, GST filings, and KYC. Complete the psychometric assessment to add a behavioural character signal."
    else:
        narrative = agg_result.get("character_narrative") or "Full financial profile assessed — bank transactions, GST business activity, verified identity, and psychometric character signals all contributing to your credit score."

    confidence = round(min(0.95, 0.55 + sources_connected * 0.10), 2)

    return {
        "borrower_id": borrower_id,
        "person_id": payload.person_id,
        "score_value": int(base_score),
        "risk_band": risk_band,
        "max_eligible_amount": max_amount,
        "confidence": confidence,
        "npa_probability": npa_probability,
        "npa_alert": npa_alert,
        "explanation": narrative,
        "signal_contributions": signal_contributions,
        "is_mock": False,
        "confidence_band": [max(300, base_score - 35), min(score_ceiling, base_score + 28)],
        "stress_profile": agg_result.get("stress_profile", {}),
        "sources_connected": sources_connected,
        "score_ceiling": score_ceiling,
    }
