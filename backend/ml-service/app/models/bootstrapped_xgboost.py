"""Pseudo-labelled XGBoost component for alternative-credit risk."""
from __future__ import annotations

from typing import Any

import numpy as np
import pandas as pd
from xgboost import XGBClassifier


class BootstrappedXGBoost:
    """Train on only the clearest 15% good and 15% risky observations."""

    feature_columns = [
        "income_regularity", "gig_income_consistency", "late_bill_payment_rate",
        "avg_days_late", "spending_volatility", "spending_to_income_ratio",
        "upi_failed_rate", "p2p_to_p2m_ratio", "gst_on_time_rate",
        "gst_avg_days_late", "psychometric_discipline_score",
        "psychometric_score_variance", "is_thin_data",
    ]

    def __init__(self, confident_fraction: float = 0.15, random_state: int = 42):
        self.confident_fraction = confident_fraction
        self.random_state = random_state
        self.model: XGBClassifier | None = None
        self.medians: pd.Series | None = None
        self.raw_score_columns: list[str] = []

    @staticmethod
    def _risk_oriented(frame: pd.DataFrame) -> pd.DataFrame:
        values = frame.copy()
        risk = pd.DataFrame(index=values.index)
        for col in values.columns:
            series = pd.to_numeric(values[col], errors="coerce")
            ranked = series.rank(pct=True, method="average").fillna(0.5)
            risk[col] = 1.0 - ranked if col in {
                "income_regularity", "gig_income_consistency", "gst_on_time_rate",
                "psychometric_discipline_score",
            } else ranked
        return risk

    def _feature_frame(self, feature_table: pd.DataFrame) -> pd.DataFrame:
        frame = feature_table.reindex(columns=self.feature_columns).apply(pd.to_numeric, errors="coerce")
        if self.medians is None:
            self.medians = frame.median(numeric_only=True).fillna(0.0)
        return frame.fillna(self.medians).fillna(0.0)

    def fit_predict(self, feature_table: pd.DataFrame) -> pd.Series:
        X = self._feature_frame(feature_table)
        raw_risk = self._risk_oriented(X)
        composite = raw_risk.mean(axis=1)
        lower, upper = composite.quantile([self.confident_fraction, 1.0 - self.confident_fraction])
        confident = (composite <= lower) | (composite >= upper)
        labels = (composite.loc[confident] >= upper).astype(int)
        if labels.nunique() < 2:
            raise ValueError("Pseudo-labelling needs confident examples from both tails.")
        self.model = XGBClassifier(
            objective="binary:logistic", n_estimators=180, max_depth=3,
            learning_rate=0.05, subsample=0.85, colsample_bytree=0.9,
            eval_metric="logloss", random_state=self.random_state, n_jobs=1,
        )
        self.model.fit(X.loc[confident], labels)
        return pd.Series(self.model.predict_proba(X)[:, 1], index=feature_table.index, name="bootstrapped_xgboost_risk")

    def predict_one(self, features: dict[str, Any]) -> float:
        if self.model is None or self.medians is None:
            return 0.5
        row = pd.DataFrame([{col: features.get(col, np.nan) for col in self.feature_columns}])
        row = row.apply(pd.to_numeric, errors="coerce").fillna(self.medians).fillna(0.0)
        return float(np.clip(self.model.predict_proba(row)[:, 1][0], 0.0, 1.0))
