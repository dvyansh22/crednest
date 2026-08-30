from __future__ import annotations

from typing import Any, Dict, List, Optional

from fastapi import APIRouter
from pydantic import BaseModel, Field

from app.config import settings
from app.features.bank_features import compute_bank_features
from app.features.cross_validation import cross_validate_gst_bank
from app.features.gst_features import compute_gst_features
from app.models.xgboost_engine.xgboost_engine import XGBoostEngine

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


def _calculate_psychometric_score(quiz_responses: List[QuizResponse]) -> Dict[str, Any]:
    risk_score = 0
    for item in quiz_responses:
        answer = str(item.answer).lower()
        if "always" in answer or "very" in answer:
            risk_score += 10
        elif "sometimes" in answer or "often" in answer:
            risk_score += 5
        elif "rarely" in answer or "never" in answer:
            risk_score -= 3
    risk_score = max(0, min(100, risk_score))
    risk_level = "Low" if risk_score < 35 else "Medium" if risk_score < 70 else "High"
    return {"risk_level": risk_level, "risk_score": risk_score}


def _build_character_narrative(bank_features: Dict[str, Any], gst_features: Dict[str, Any], psychometric: Dict[str, Any]) -> str:
    gig_signal = "steady gig income" if bank_features.get("gig_income", 0) > 0 else "limited alternate income"
    gst_signal = "sound GST discipline" if gst_features.get("filing_punctuality", 0) >= 70 else "irregular GST compliance"
    risk_signal = "balanced financial habits" if psychometric["risk_level"] != "High" else "higher reliance on short-term cash flow"
    return (
        f"Borrower shows {gig_signal}, {gst_signal}, and {risk_signal}. "
        f"Income regularity score is {bank_features.get('income_regularity_score', 50)} with a current cash-flow velocity of {bank_features.get('cash_flow_velocity', 1)}."
    )


@router.post("", response_model=ScoreResponse)
def score_borrower(payload: ScoreRequest):
    xgboost_engine = XGBoostEngine()
    feature_payload = getattr(payload, "features", None) or {}

    if not feature_payload:
        bank_features = compute_bank_features(payload.bank_statement)
        gst_features = compute_gst_features(payload.gst_data or {})
        cross_validation = cross_validate_gst_bank(payload.gst_data or {}, payload.bank_statement)
        psychometric = _calculate_psychometric_score(payload.quiz_responses)
        feature_payload = {
            "income_regularity": float(bank_features.get("income_regularity_score", 50)) / 100.0,
            "gig_income_consistency": 1.0 if bank_features.get("gig_income", 0) > 0 else 0.0,
            "late_bill_payment_rate": float(abs(cross_validation.get("discrepancy_ratio", 0.0)) / 10.0),
            "avg_days_late": float(abs(cross_validation.get("discrepancy_ratio", 0.0)) * 10.0),
            "spending_volatility": float(min(1.0, abs(bank_features.get("cash_flow_velocity", 1.0) - 1.0))),
            "spending_to_income_ratio": float(min(1.0, bank_features.get("credit_to_debit_ratio", 1.0))),
            "avg_monthly_upi_count": float(max(0.0, bank_features.get("transaction_count", 0) / 4.0)),
            "avg_monthly_upi_volume": float(bank_features.get("monthly_inflow", 0) / 1000.0),
            "upi_failed_rate": 0.0,
            "p2p_to_p2m_ratio": 1.0,
            "gst_on_time_rate": float(min(1.0, gst_features.get("filing_punctuality", 0) / 100.0)),
            "gst_avg_days_late": float(max(0.0, 100.0 - gst_features.get("filing_punctuality", 100))),
            "gst_turnover_trend": float(min(1.0, abs(gst_features.get("turnover_trend", 0.0)) / 100.0)),
            "has_gst_data": 1.0 if (payload.gst_data or {}) else 0.0,
            "psychometric_discipline_score": float(max(0.0, 1.0 - (psychometric.get("risk_score", 0) / 100.0))),
            "psychometric_score_variance": float(min(1.0, psychometric.get("risk_score", 0) / 100.0)),
            "avg_response_time_seconds": 25.0,
        }

    model_prediction = xgboost_engine.predict(feature_payload)
    borrower_id = payload.borrower_id or payload.person_id or "unknown"

    base_score = int(model_prediction.get("credit_score", 550))
    confidence_low = max(settings.min_score, int(model_prediction.get("score_band", [base_score, base_score])[0]))
    confidence_high = min(settings.max_score, int(model_prediction.get("score_band", [base_score, base_score])[1]))

    npa_alert = None
    npa_probability = 1.0 - float(model_prediction.get("probability", 0.5))
    
    if payload.location and "latitude" in payload.location and "longitude" in payload.location:
        import math
        lat = payload.location["latitude"]
        lon = payload.location["longitude"]
        hubs = [(28.61, 77.20), (19.07, 72.87), (12.97, 77.59), (22.90, 79.08), (26.84, 80.94)]
        dist = min(math.sqrt((lat - h[0])**2 + (lon - h[1])**2) for h in hubs)
        
        if dist > 5.0:  # Far outside expected economic zones
            npa_alert = "Fraud Risk: Suspicious Location Activity. Coordinates fall significantly outside expected operating bounds."
            npa_probability = max(0.95, npa_probability)
            base_score = min(base_score, 400) # Penalize score
            model_prediction["predicted_class"] = "P4"

    signal_contributions = [
        {"signal": "risk_anomaly", "impact": f"{model_prediction.get('feature_importance', {}).get('anomaly_norm', 0.0):.2f}"},
        {"signal": "composite_risk", "impact": f"{model_prediction.get('feature_importance', {}).get('composite_risk', 0.0):.2f}"},
        {"signal": "model_decision", "impact": f"{model_prediction.get('predicted_class', 'P2')}@{model_prediction.get('probability', 0.5):.2f}"},
    ]

    return {
        "borrower_id": borrower_id,
        "person_id": payload.person_id,
        "score_value": int(base_score),
        "risk_band": model_prediction.get("predicted_class", "P2"),
        "max_eligible_amount": 100000 if base_score >= 720 else (50000 if base_score >= 580 else 25000),
        "confidence": float(model_prediction.get("probability", 0.5)),
        "npa_probability": npa_probability,
        "npa_alert": npa_alert,
        "explanation": f"Risk tier {model_prediction.get('predicted_class', 'P2')} generated from alternative-data anomaly and explainable composite risk over income regularity, GST discipline, and psychometric stability.",
        "signal_contributions": signal_contributions,
        "is_mock": False,
        "confidence_band": [int(confidence_low), int(confidence_high)],
        "stress_profile": {
            "adverse_income_score": max(settings.min_score, base_score - 40),
            "min_emi_floor": max(900, int((base_score / 100.0) * 22)),
        }
    }
