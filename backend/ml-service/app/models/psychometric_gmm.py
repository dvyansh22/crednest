"""Psychometric-response archetype clustering component."""
from __future__ import annotations

from typing import Any

import numpy as np
import pandas as pd
from sklearn.mixture import GaussianMixture
from sklearn.preprocessing import StandardScaler


class PsychometricGMM:
    def __init__(self, n_components: int = 5, random_state: int = 42):
        self.n_components = n_components
        self.random_state = random_state
        self.scaler = StandardScaler()
        self.model: GaussianMixture | None = None
        self.cluster_risk_: dict[int, float] = {}
        self.person_scores_: dict[str, float] = {}

    @staticmethod
    def _matrix(psych_df: pd.DataFrame, person_ids: pd.Series) -> tuple[pd.DataFrame, pd.Series]:
        mapping = {"A": 4.0, "B": 3.0, "C": 2.0, "D": 1.0}
        answers = [col for col in psych_df.columns if col.startswith("q") and col.endswith("_answer")]
        times = [col for col in psych_df.columns if col.startswith("response_time_seconds_")]
        raw = psych_df.copy()
        for column in answers:
            raw[column] = raw[column].astype(str).str.upper().map(mapping).fillna(2.5)
        for column in times:
            raw[column] = pd.to_numeric(raw[column], errors="coerce").fillna(raw[column].median())
        aggregate = raw.groupby("person_id")[answers + times].mean()
        index = pd.Index([str(value) for value in person_ids], name="person_id")
        matrix = aggregate.reindex(index).fillna(aggregate.median(numeric_only=True)).fillna(0.0)
        discipline = matrix[answers].mean(axis=1) / 4.0
        return matrix, discipline

    def fit_predict(self, psych_df: pd.DataFrame, feature_table: pd.DataFrame) -> pd.Series:
        matrix, discipline = self._matrix(psych_df, feature_table["person_id"])
        X = self.scaler.fit_transform(matrix)
        self.model = GaussianMixture(n_components=min(self.n_components, len(matrix)), covariance_type="diag", random_state=self.random_state)
        clusters = self.model.fit_predict(X)
        cluster_discipline = pd.DataFrame({"cluster": clusters, "discipline": discipline.to_numpy()}).groupby("cluster")["discipline"].mean()
        # Lower cluster-average discipline means a higher risk-leaning archetype percentile.
        ordered = cluster_discipline.rank(method="average", ascending=False, pct=True)
        self.cluster_risk_ = {int(cluster): float(score) for cluster, score in ordered.items()}
        scores = np.array([self.cluster_risk_[int(cluster)] for cluster in clusters])
        self.person_scores_ = dict(zip(matrix.index.astype(str), scores.astype(float)))
        return pd.Series(scores, index=feature_table.index, name="psychometric_gmm_risk")

    def predict_one(self, features: dict[str, Any], person_id: str | None = None) -> float:
        if person_id is not None and str(person_id) in self.person_scores_:
            return float(self.person_scores_[str(person_id)])
        discipline = float(features.get("psychometric_discipline_score", 0.5) or 0.5)
        return float(np.clip(1.0 - discipline, 0.0, 1.0))
