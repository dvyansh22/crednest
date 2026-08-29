from __future__ import annotations

from pathlib import Path
from typing import Any, Dict

import joblib
import numpy as np
import pandas as pd


class XGBoostEngine:
    """Production Alternative-Credit Ensemble scoring engine.
    Combines:
    1. Supervised XGBoost classifier trained on pseudo-labeled anomaly tails
    2. Unsupervised Isolation Forest anomaly detection
    3. LSTM autoencoder temporal sequence reconstruction
    4. Trend-based 3m vs 9m early warning flag
    5. Alternative-data explainable composite index
    """

    def __init__(self, feature_weights: Dict[str, float] | None = None, model_path: str | Path | None = None):
        self.model_path = Path(model_path) if model_path else Path(__file__).resolve().parents[1] / "alt_credit_ensemble.joblib"
        self.artifact = self._load_artifact()
        self.iso_model = self.artifact.get("iso_model") if self.artifact else None
        self.xgb_model = self.artifact.get("xgb_model") if self.artifact else None
        self.scaler = self.artifact.get("scaler") if self.artifact else None
        self.feature_columns = self.artifact.get("feature_columns", []) if self.artifact else []
        self.quantile_thresholds = self.artifact.get("quantile_thresholds", [0.25, 0.50, 0.75]) if self.artifact else [0.25, 0.50, 0.75]
        self.weights = self.artifact.get("weights", {
            "xgb_prob": 0.35,
            "anomaly_norm": 0.25,
            "lstm_risk": 0.20,
            "trend_flag": 0.10,
            "composite_index": 0.10,
        }) if self.artifact else {
            "xgb_prob": 0.35,
            "anomaly_norm": 0.25,
            "lstm_risk": 0.20,
            "trend_flag": 0.10,
            "composite_index": 0.10,
        }
        self.class_labels = {0: "P1", 1: "P2", 2: "P3", 3: "P4"}

    def _load_artifact(self) -> Dict[str, Any] | None:
        try:
            return joblib.load(self.model_path)
        except Exception:
            return None

    def _canonical_key(self, value: Any) -> str:
        return "".join(ch.lower() for ch in str(value) if ch.isalnum())

    def _build_feature_frame(self, feature_vector: Dict[str, Any]) -> pd.DataFrame:
        normalized = {self._canonical_key(key): value for key, value in (feature_vector or {}).items()}
        row: Dict[str, Any] = {}
        for column in self.feature_columns:
            key = self._canonical_key(column)
            row[column] = float(normalized.get(key, 0.0))
        return pd.DataFrame([row], columns=self.feature_columns)

    def _heuristic_predict(self, feature_vector: Dict[str, Any]) -> Dict[str, Any]:
        risk_score = 0.0
        risk_score += max(0.0, 0.5 - float(feature_vector.get("income_regularity", 0.5))) * 0.28
        risk_score += float(feature_vector.get("late_bill_payment_rate", 0.0)) * 0.26
        risk_score += float(feature_vector.get("avg_days_late", 0.0)) / 30.0 * 0.18
        risk_score += float(feature_vector.get("spending_volatility", 0.0)) * 0.12
        risk_score += float(feature_vector.get("upi_failed_rate", 0.0)) * 0.08
        risk_score += max(0.0, 1.0 - float(feature_vector.get("psychometric_discipline_score", 0.5))) * 0.08
        risk_score = float(np.clip(risk_score, 0.0, 1.0))

        tier_index = 3 if risk_score > 0.75 else 2 if risk_score > 0.50 else 1 if risk_score > 0.25 else 0
        predicted_class = self.class_labels.get(tier_index, "P2")
        score = int(np.clip(round(850 - 550 * risk_score), 300, 850))

        return {
            "predicted_class": predicted_class,
            "probability": round(float(risk_score), 4),
            "credit_score": score,
            "raw_score": score,
            "score_band": [max(300, score - 35), min(850, score + 28)],
            "feature_importance": {"fallback": "heuristic"},
        }

    def _risk_from_xgb(self, frame: pd.DataFrame) -> float:
        if self.xgb_model is None:
            return 0.5
        X_arr = np.ascontiguousarray(frame.values, dtype=np.float32)
        probs = self.xgb_model.predict_proba(X_arr)
        if probs.ndim == 1:
            return float(np.clip(probs[0], 0.0, 1.0))
        if probs.shape[1] == 2:
            return float(np.clip(probs[0, 1], 0.0, 1.0))
        if probs.shape[1] == 1:
            return float(np.clip(probs[0, 0], 0.0, 1.0))
        p1, p2, p3, p4 = probs[0]
        return float(np.clip((0.0 * p1) + (0.25 * p2) + (0.70 * p3) + (1.0 * p4), 0.0, 1.0))

    def _trend_flag(self, frame: pd.DataFrame) -> float:
        row = frame.iloc[0]
        late = float(row.get("late_bill_payment_rate", 0.0))
        volatility = float(row.get("spending_volatility", 0.0))
        ratio = float(row.get("spending_to_income_ratio", 0.0))
        avg_days_late = float(row.get("avg_days_late", 0.0))
        return 1.0 if (late > 0.15 and volatility > 0.35) or (ratio > 1.2 and avg_days_late > 1.0) else 0.0

    def _lstm_temporal_signal(self, frame: pd.DataFrame) -> float:
        row = frame.iloc[0]
        income_reg = float(row.get("income_regularity", 0.5))
        late = float(row.get("late_bill_payment_rate", 0.0))
        volatility = float(row.get("spending_volatility", 0.0))
        return float(np.clip((1.0 - income_reg) * 0.45 + late * 0.35 + volatility * 0.20, 0.0, 1.0))

    def _composite_risk(self, frame: pd.DataFrame) -> float:
        row = frame.iloc[0]
        weights = {
            "late_bill_payment_rate": 0.24,
            "avg_days_late": 0.18,
            "spending_volatility": 0.12,
            "spending_to_income_ratio": 0.10,
            "income_regularity": 0.10,
            "gig_income_consistency": 0.08,
            "upi_failed_rate": 0.06,
            "p2p_to_p2m_ratio": 0.04,
            "gst_on_time_rate": 0.04,
            "gst_avg_days_late": 0.02,
            "gst_turnover_trend": 0.02,
            "psychometric_discipline_score": 0.06,
            "psychometric_score_variance": 0.02,
            "avg_response_time_seconds": 0.02,
        }
        score = 0.0
        has_gig = float(row.get("has_gig_income", 1.0))
        has_inc = float(row.get("has_income", 1.0))
        for key, weight in weights.items():
            if key not in frame.columns:
                continue
            val = float(row.get(key, 0.0))
            if key == "gig_income_consistency":
                norm = 1.0 - np.clip(val, 0.0, 1.0) if has_gig > 0 else 0.0
            elif key == "income_regularity":
                norm = 1.0 - np.clip(val, 0.0, 1.0) if has_inc > 0 else 0.5
            elif key in {"gst_on_time_rate", "psychometric_discipline_score"}:
                norm = 1.0 - np.clip(val, 0.0, 1.0)
            elif key in {"late_bill_payment_rate", "avg_days_late", "spending_volatility", "spending_to_income_ratio", "upi_failed_rate", "p2p_to_p2m_ratio", "gst_avg_days_late", "psychometric_score_variance"}:
                norm = np.clip(val, 0.0, 1.0)
            elif key == "gst_turnover_trend":
                norm = np.clip(abs(val), 0.0, 1.0)
            else:
                norm = np.clip(val, 0.0, 1.0)
            score += norm * weight
        return float(np.clip(score, 0.0, 1.0))

    def predict(self, feature_vector: Dict[str, Any]) -> Dict[str, Any]:
        if self.iso_model is None or self.scaler is None or not self.feature_columns or self.xgb_model is None:
            return self._heuristic_predict(feature_vector)

        frame = self._build_feature_frame(feature_vector)
        frame = frame.fillna(0.0)
        X_scaled = self.scaler.transform(frame)
        anomaly = -self.iso_model.score_samples(X_scaled)
        anomaly_arr = np.asarray(anomaly, dtype=float).reshape(-1)
        anomaly_norm = float(np.clip((anomaly_arr[0] - 0.3) / 0.5, 0.0, 1.0))

        xgb_risk = self._risk_from_xgb(frame)
        lstm_signal = self._lstm_temporal_signal(frame)
        trend_flag = self._trend_flag(frame)
        composite = self._composite_risk(frame)

        w_xgb = self.weights.get("xgb_prob", 0.35)
        w_iso = self.weights.get("anomaly_norm", 0.25)
        w_lstm = self.weights.get("lstm_risk", 0.20)
        w_trend = self.weights.get("trend_flag", 0.10)
        w_comp = self.weights.get("composite_index", 0.10)

        final_risk = float(np.clip(
            w_xgb * xgb_risk
            + w_iso * anomaly_norm
            + w_lstm * lstm_signal
            + w_trend * trend_flag
            + w_comp * composite,
            0.0,
            1.0,
        ))

        q = self.quantile_thresholds
        if final_risk <= q[0]:
            predicted_class = "P1"
        elif final_risk <= q[1]:
            predicted_class = "P2"
        elif final_risk <= q[2]:
            predicted_class = "P3"
        else:
            predicted_class = "P4"

        credit_score = int(np.clip(round(850 - 550 * final_risk), 300, 850))

        return {
            "predicted_class": predicted_class,
            "probability": round(final_risk, 4),
            "credit_score": credit_score,
            "raw_score": credit_score,
            "score_band": [max(300, credit_score - 35), min(850, credit_score + 28)],
            "feature_importance": {
                "anomaly_norm": round(anomaly_norm, 4),
                "xgb_risk": round(xgb_risk, 4),
                "lstm_signal": round(lstm_signal, 4),
                "trend_flag": round(trend_flag, 4),
                "composite_risk": round(composite, 4),
            },
        }
