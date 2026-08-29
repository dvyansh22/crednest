"""Twelve-month deterioration detector for NPA early-warning risk."""
from __future__ import annotations

from typing import Any

import numpy as np
import pandas as pd


class NPAEarlyWarning:
    def __init__(self):
        self.person_scores_: dict[str, float] = {}

    def fit_predict(self, bank_df: pd.DataFrame, feature_table: pd.DataFrame) -> pd.Series:
        data = bank_df[["person_id", "date", "type", "amount", "narration"]].copy()
        data["date"] = pd.to_datetime(data["date"], errors="coerce")
        data = data.dropna(subset=["date"])
        data["month"] = data["date"].dt.to_period("M")
        months = pd.period_range(data["month"].min(), data["month"].max(), freq="M")[-12:]
        ids = [str(value) for value in feature_table["person_id"]]
        debits = data[data["type"].astype(str).str.lower().eq("debit")].copy()
        debits["late"] = debits["narration"].fillna("").str.contains("late|emi|bill|payment|credit card", case=False, regex=True).astype(float)
        late_rate = debits.groupby(["person_id", "month"])["late"].agg(["sum", "count"])
        late_rate["value"] = late_rate["sum"] / late_rate["count"].clip(lower=1)
        income = data[data["type"].astype(str).str.lower().eq("credit")].groupby(["person_id", "month"])["amount"].sum()
        index = pd.MultiIndex.from_product([ids, months], names=["person_id", "month"])
        late_matrix = late_rate["value"].reindex(index, fill_value=0.0).to_numpy().reshape(len(ids), 12)
        income_matrix = income.reindex(index, fill_value=0.0).to_numpy().reshape(len(ids), 12)
        x = np.arange(12, dtype=float)
        late_slopes = np.array([np.polyfit(x, row, 1)[0] for row in late_matrix])
        income_slopes = np.array([np.polyfit(x, row, 1)[0] / max(row.mean(), 1.0) for row in income_matrix])
        late_risk = pd.Series(late_slopes).rank(pct=True).to_numpy()
        income_risk = 1.0 - pd.Series(income_slopes).rank(pct=True).to_numpy()
        scores = np.clip(0.6 * late_risk + 0.4 * income_risk, 0.0, 1.0)
        self.person_scores_ = dict(zip(ids, scores.astype(float)))
        return pd.Series(scores, index=feature_table.index, name="npa_early_warning_risk")

    def predict_one(self, features: dict[str, Any], person_id: str | None = None) -> float:
        if person_id is not None and str(person_id) in self.person_scores_:
            return float(self.person_scores_[str(person_id)])
        return float(np.clip(float(features.get("late_bill_payment_rate", 0.0) or 0.0), 0.0, 1.0))
