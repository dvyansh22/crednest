from __future__ import annotations

from typing import Any, Dict


class NPAEarlyWarningModel:
    def __init__(self):
        self.default_threshold = 0.55

    def predict(self, signal_data: Dict[str, Any]) -> Dict[str, Any]:
       salary_gap = float(signal_data.get("salary_gap_days", 0) or 0)
        gst_gap = float(signal_data.get("gst_filing_gap_days", 0) or 0)
        risk = min(1.0, (salary_gap / 30.0 + gst_gap / 45.0) / 2.0)
        alert = risk >= self.default_threshold
        return {
            "alert": alert,
            "risk_probability": round(max(0.0, min(1.0, risk)), 3),
            "suggested_restructuring": alert,
            "reason": "salary_gap_or_gst_gap_detected" if alert else "stable",
        }
