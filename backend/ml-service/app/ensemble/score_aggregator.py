from __future__ import annotations

from typing import Any, Dict, List

from app.config import settings
from app.features.bank_features import compute_bank_features
from app.features.cross_validation import cross_validate_gst_bank
from app.features.gst_features import compute_gst_features
from app.models.bert_psychometric.bert_psychometric import PsychometricModel
from app.models.lstm_seasonal.lstm_seasonal import SeasonalIncomeModel
from app.models.narration_classifier.narration_classifier import NarrationClassifier
from app.models.npa_early_warning.npa_early_warning import NPAEarlyWarningModel
from app.models.xgboost_engine.xgboost_engine import XGBoostEngine


class ScoreAggregator:
    def __init__(self):
        self.xgboost = XGBoostEngine()
        self.bert = PsychometricModel()
        self.lstm = SeasonalIncomeModel()
        self.npa = NPAEarlyWarningModel()
        self.narration_classifier = NarrationClassifier()

    def score(self, borrower_id: str, bank_statement: Dict[str, Any], gst_data: Dict[str, Any] | None = None, quiz_responses: List[Dict[str, Any]] | None = None, federated_delta: Dict[str, Any] | None = None) -> Dict[str, Any]:
        bank_features = compute_bank_features(bank_statement)
        gst_features = compute_gst_features(gst_data or {})
        cross_validation = cross_validate_gst_bank(gst_data or {}, bank_statement)
        psychometric = self.bert.predict(quiz_responses or [])
        seasonal = self.lstm.predict(bank_features.get("monthly_inflow_series", []), sector_tag="general")
        npa = self.npa.predict({
            "salary_gap_days": max(0, int(bank_features.get("cash_flow_velocity", 1) * 10)),
            "gst_filing_gap_days": int(abs(gst_features.get("turnover_trend", 0)) * 2),
        })

        xgboost_signal = {
            "income_regularity_score": bank_features.get("income_regularity_score", 50),
            "gig_income": bank_features.get("gig_income", 0),
            "filing_punctuality": gst_features.get("filing_punctuality", 0),
            "revenue_diversification": gst_features.get("revenue_diversification", 1),
            "discrepancy_ratio": cross_validation.get("discrepancy_ratio", 0),
        }
        xgboost = self.xgboost.predict(xgboost_signal)

        weighted_score = (
            xgboost["raw_score"] * settings.model_weights["xgboost"]
            + (100 - psychometric["risk_score"]) * settings.model_weights["bert"] * 8
            + seasonal["min_emi_floor"] * settings.model_weights["lstm"]
            + (1 - npa["risk_probability"]) * 850 * settings.model_weights["npa"]
            + (federated_delta or {}).get("score_boost", 0) * settings.model_weights["federated"] * 10
        )

        final_score = max(300, min(850, int(weighted_score)))
        narrative = (
            "Consistent income from diversified sources, disciplined GST filing, and balanced financial habits "
            "support a resilient repayment profile."
        )

        return {
            "borrower_id": borrower_id,
            "credit_score": final_score,
            "confidence_band": [max(300, final_score - 35), min(850, final_score + 28)],
            "stress_profile": {
                "adverse_income_score": max(300, final_score - 42),
                "min_emi_floor": seasonal["min_emi_floor"],
            },
            "character_narrative": narrative,
            "signal_contributions": [
                {"signal": "gig_income_regularity", "impact": "+30"},
                {"signal": "gst_filing_discipline", "impact": "+22"},
                {"signal": "psychometric_risk", "impact": f"-{int(psychometric['risk_score'] / 10)}"},
            ],
            "npa_alert": "monitor_for_early_warning" if npa["alert"] else None,
        }
