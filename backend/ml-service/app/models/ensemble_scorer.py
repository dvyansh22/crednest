"""Four-component alternative-credit ensemble and P1--P4 tiering."""
from __future__ import annotations

from pathlib import Path
from typing import Any

import joblib
import numpy as np
import pandas as pd

from app.models.bootstrapped_xgboost import BootstrappedXGBoost
from app.models.lstm_seasonal import LSTMSeasonalAutoencoder
from app.models.npa_early_warning import NPAEarlyWarning
from app.models.psychometric_gmm import PsychometricGMM


class EnsembleScorer:
    """Combines supervised, seasonal, psychometric, and trend risk signals.

    Weights are intentionally fixed: pseudo-labelled XGBoost 40%, LSTM seasonal
    reconstruction error 25%, psychometric archetype 20%, and NPA trend 15%.
    """

    weights = {
        "bootstrapped_xgboost_risk": 0.40,
        "lstm_seasonal_risk": 0.25,
        "psychometric_gmm_risk": 0.20,
        "npa_early_warning_risk": 0.15,
    }
    tier_quantiles = (0.11, 0.74, 0.89)

    def __init__(self, artifact_path: str | Path | None = None):
        self.artifact_path = Path(artifact_path) if artifact_path else Path(__file__).resolve().parent / "alt_credit_ensemble.joblib"
        self.bootstrapped_xgboost: BootstrappedXGBoost | None = None
        self.lstm_seasonal: LSTMSeasonalAutoencoder | None = None
        self.psychometric_gmm: PsychometricGMM | None = None
        self.npa_early_warning: NPAEarlyWarning | None = None
        self.quantile_thresholds = np.array(self.tier_quantiles, dtype=float)
        self._load()

    def _load(self) -> None:
        if not self.artifact_path.exists():
            return
        artifact = joblib.load(self.artifact_path)
        self.bootstrapped_xgboost = artifact["bootstrapped_xgboost"]
        self.lstm_seasonal = artifact["lstm_seasonal"]
        self.psychometric_gmm = artifact["psychometric_gmm"]
        self.npa_early_warning = artifact["npa_early_warning"]
        self.quantile_thresholds = np.asarray(artifact["quantile_thresholds"], dtype=float)

    @staticmethod
    def assign_tiers(risk_scores: pd.Series, quantiles: tuple[float, float, float] = tier_quantiles) -> tuple[pd.Series, np.ndarray]:
        thresholds = np.quantile(risk_scores, quantiles)
        tiers = pd.Series("P2", index=risk_scores.index, dtype=object)
        tiers[risk_scores <= thresholds[0]] = "P1"
        tiers[(risk_scores > thresholds[1]) & (risk_scores <= thresholds[2])] = "P3"
        tiers[risk_scores > thresholds[2]] = "P4"
        return tiers, thresholds

    def fit(self, feature_table: pd.DataFrame, bank_df: pd.DataFrame, psych_df: pd.DataFrame) -> pd.DataFrame:
        self.bootstrapped_xgboost = BootstrappedXGBoost()
        boot = self.bootstrapped_xgboost.fit_predict(feature_table)
        normal_mask = boot <= boot.quantile(0.70)
        self.lstm_seasonal = LSTMSeasonalAutoencoder()
        seasonal = self.lstm_seasonal.fit_predict(bank_df, feature_table, normal_mask)
        self.psychometric_gmm = PsychometricGMM()
        psychometric = self.psychometric_gmm.fit_predict(psych_df, feature_table)
        self.npa_early_warning = NPAEarlyWarning()
        npa = self.npa_early_warning.fit_predict(bank_df, feature_table)

        result = feature_table.copy()
        result[boot.name] = boot
        result[seasonal.name] = seasonal
        result[psychometric.name] = psychometric
        result[npa.name] = npa
        result["final_risk_score"] = sum(result[column] * weight for column, weight in self.weights.items()).clip(0.0, 1.0)
        result["tier"], self.quantile_thresholds = self.assign_tiers(result["final_risk_score"])
        self.artifact_path.parent.mkdir(parents=True, exist_ok=True)
        joblib.dump({
            "bootstrapped_xgboost": self.bootstrapped_xgboost,
            "lstm_seasonal": self.lstm_seasonal,
            "psychometric_gmm": self.psychometric_gmm,
            "npa_early_warning": self.npa_early_warning,
            "quantile_thresholds": self.quantile_thresholds.tolist(),
            "weights": self.weights,
        }, self.artifact_path)
        return result

    def predict(self, features: dict[str, Any], person_id: str | None = None) -> dict[str, Any]:
        if not all([self.bootstrapped_xgboost, self.lstm_seasonal, self.psychometric_gmm, self.npa_early_warning]):
            raise RuntimeError("Ensemble artifact is unavailable. Run training/train_ensemble_risk_model.py first.")
        signals = {
            "bootstrapped_xgboost_risk": self.bootstrapped_xgboost.predict_one(features),
            "lstm_seasonal_risk": self.lstm_seasonal.predict_one(person_id),
            "psychometric_gmm_risk": self.psychometric_gmm.predict_one(features, person_id),
            "npa_early_warning_risk": self.npa_early_warning.predict_one(features, person_id),
        }
        risk = float(np.clip(sum(signals[name] * weight for name, weight in self.weights.items()), 0.0, 1.0))
        lower, middle, upper = self.quantile_thresholds
        tier = "P1" if risk <= lower else "P2" if risk <= middle else "P3" if risk <= upper else "P4"
        credit_score = int(np.clip(round(850 - 550 * risk), 300, 850))
        return {
            "predicted_class": tier,
            "probability": round(risk, 4),
            "credit_score": credit_score,
            "raw_score": round(risk, 4),
            "score_band": [max(300, credit_score - 35), min(850, credit_score + 28)],
            "feature_importance": {name: round(value, 4) for name, value in signals.items()},
        }
