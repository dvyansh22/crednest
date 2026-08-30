from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, Iterable
import joblib
import numpy as np


class SeasonalIncomeModel:
    """
    Seasonal Income & Volatility Estimator.
    Primary Path: Trained Keras LSTM regressor (seasonal_income_lstm.joblib) measuring temporal volatility 
    from a 1D income inflow series, leveraging synthetic profiles and per-sequence min-max scaling to prevent saturation bias.
    Fallback Path: Analytical statistical estimator measuring coefficient of variation and month-over-month
    cashflow velocity if the LSTM fails to load or errors.
    """

    def __init__(self, model_path: str | Path | None = None, use_experimental_lstm: bool = True):
        self.use_experimental_lstm = use_experimental_lstm
        self.model_path = Path(model_path) if model_path else Path(__file__).resolve().parents[1] / "seasonal_income_lstm.joblib"
        self._lstm_artifact = None
        self._lstm_model = None

    def _get_lstm_model(self):
        if self._lstm_model is None and self.model_path.exists():
            try:
                import tensorflow as tf
                from tensorflow.keras import layers, models

                self._lstm_artifact = joblib.load(self.model_path)
                weights = self._lstm_artifact.get("weights")
                if weights:
                    model = models.Sequential([
                        layers.Input(shape=(12, 1), name="input_12m_inflow"),
                        layers.LSTM(16, return_sequences=False, name="lstm_temporal_extractor"),
                        layers.Dropout(0.2, name="lstm_dropout"),
                        layers.Dense(8, activation="relu", name="dense_hidden"),
                        layers.Dropout(0.1, name="dense_dropout"),
                        layers.Dense(1, activation="sigmoid", name="volatility_output")
                    ])
                    model.set_weights(weights)
                    self._lstm_model = model
            except Exception:
                self._lstm_model = None
        return self._lstm_model

    def predict(self, income_series: Iterable[float], sector_tag: str = "general") -> Dict[str, Any]:
        values = self._valid_monthly_values(income_series)
        if not values:
            return {
                "volatility_band": "stable",
                "min_emi_floor": 900,
                "seasonal_signal": 0.0,
                "series_months": 0,
                "sector_tag": sector_tag,
            }

        mean_value = sum(values) / len(values)

        # 1. Experimental LSTM path (if explicitly enabled)
        if self.use_experimental_lstm:
            lstm = self._get_lstm_model()
            if lstm is not None:
                try:
                    if len(values) >= 12:
                        seq_12 = np.array(values[-12:], dtype=np.float32)
                    else:
                        seq_12 = np.pad(np.array(values, dtype=np.float32), (12 - len(values), 0), mode="edge")

                    seq_mean = np.mean(seq_12)
                    if seq_mean < 1e-6:
                        normalized = np.zeros((1, 12), dtype=np.float32)
                    else:
                        normalized = (seq_12 / seq_mean).reshape(1, 12)

                    X_tensor = normalized[..., np.newaxis]

                    pred = lstm.predict(X_tensor, verbose=0)
                    volatility = float(np.clip(pred[0, 0], 0.0, 1.0))
                    band = "stable" if volatility < 0.20 else "moderate" if volatility < 0.45 else "volatile"
                    min_emi_floor = max(900, int(mean_value * (0.08 if band == "stable" else 0.06 if band == "moderate" else 0.04)))

                    return {
                        "volatility_band": band,
                        "min_emi_floor": min_emi_floor,
                        "seasonal_signal": round(volatility, 4),
                        "series_months": len(values),
                        "sector_tag": sector_tag,
                    }
                except Exception:
                    pass

        # 2. Primary Path: Robust Statistical Estimator
        return self._heuristic_predict(values, mean_value, sector_tag)

    def _heuristic_predict(self, values: list[float], mean_value: float, sector_tag: str) -> Dict[str, Any]:
        variance = sum((value - mean_value) ** 2 for value in values) / len(values)
        coefficient_of_variation = variance**0.5 / max(mean_value, 1.0)
        month_to_month_changes = [
            abs(current - previous) / max(previous, 1.0)
            for previous, current in zip(values, values[1:])
        ]
        average_change = sum(month_to_month_changes) / len(month_to_month_changes) if month_to_month_changes else 0.0
        volatility = min(1.0, 0.65 * coefficient_of_variation + 0.35 * average_change)

        if volatility < 0.12:
            band = "stable"
        elif volatility < 0.25:
            band = "moderate"
        else:
            band = "volatile"

        min_emi_floor = max(900, int(mean_value * (0.08 if band == "stable" else 0.06 if band == "moderate" else 0.04)))
        return {
            "volatility_band": band,
            "min_emi_floor": min_emi_floor,
            "seasonal_signal": round(volatility, 4),
            "series_months": len(values),
            "sector_tag": sector_tag,
        }

    @staticmethod
    def _valid_monthly_values(income_series: Iterable[float]) -> list[float]:
        values = []
        for value in income_series:
            try:
                values.append(max(0.0, float(value)))
            except (TypeError, ValueError):
                continue
        return values
