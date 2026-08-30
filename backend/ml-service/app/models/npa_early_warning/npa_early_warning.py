from __future__ import annotations

import math
from typing import Any, Dict, List
from pathlib import Path
import joblib

class NPAEarlyWarningModel:
    def __init__(self):
        self.default_threshold = 0.55
        self.model_path = Path(__file__).resolve().parents[1] / "npa_early_warning_xgboost.joblib"
        self._model = None
        try:
            if self.model_path.exists():
                self._model = joblib.load(self.model_path)
        except Exception:
            self._model = None

    def _pad_to_sequence(self, value: Any) -> List[float]:
        """Pads a single scalar or short list into a 6-month historical sequence."""
        if isinstance(value, list):
            seq = [self._non_negative_float(v) for v in value]
            if not seq:
                return [0.0] * 6
            if len(seq) >= 6:
                return seq[-6:]
            return [seq[0]] * (6 - len(seq)) + seq
        else:
            return [self._non_negative_float(value)] * 6

    def predict(self, signal_data: Dict[str, Any]) -> Dict[str, Any]:
        raw_salary = signal_data.get("salary_gap_days")
        raw_gst = signal_data.get("gst_filing_gap_days")
        
        is_genuine_sequence = isinstance(raw_salary, list) and len(raw_salary) >= 2

        # Handle either a 6-month history list or a single point-in-time scalar
        salary_gaps = self._pad_to_sequence(raw_salary)
        gst_gaps = self._pad_to_sequence(raw_gst)

        # Primary Path: Trained XGBoost Model on 6-month trajectories
        # Only use this if we have a genuine historical sequence, not a padded scalar
        if self._model is not None and is_genuine_sequence:
            try:
                import pandas as pd
                feature_dict = {}
                for i in range(1, 7):
                    feature_dict[f"salary_gap_m{i}"] = [salary_gaps[i-1]]
                for i in range(1, 7):
                    feature_dict[f"gst_gap_m{i}"] = [gst_gaps[i-1]]
                df = pd.DataFrame(feature_dict)
                risk = float(self._model.predict_proba(df)[0, 1])
                alert = risk >= self.default_threshold
                return {
                    "alert": alert,
                    "risk_probability": round(max(0.0, min(1.0, risk)), 3),
                    "suggested_restructuring": alert,
                    "reason": "degrading_behavior_trajectory_detected" if alert else "stable",
                }
            except Exception as e:
                print(f"XGBOOST FAILURE: {e}")
                pass # Fallback to logistic if execution fails

        # Fallback Path: Original Analytic Logistic Formula (uses most recent gap)
        # This is the primary path for single point-in-time scores (e.g. pre-disbursement)
        salary_gap = salary_gaps[-1]
        gst_gap = gst_gaps[-1]

        logit = -2.5 + 0.05 * min(salary_gap, 90.0) + 0.04 * min(gst_gap, 90.0)
        risk = 1.0 / (1.0 + math.exp(-logit))
        alert = risk >= self.default_threshold
        return {
            "alert": alert,
            "risk_probability": round(max(0.0, min(1.0, risk)), 3),
            "suggested_restructuring": alert,
            "reason": "salary_gap_or_gst_gap_detected" if alert else "stable",
        }

    @staticmethod
    def _non_negative_float(value: Any) -> float:
        try:
            return max(0.0, float(value or 0.0))
        except (TypeError, ValueError):
            return 0.0
