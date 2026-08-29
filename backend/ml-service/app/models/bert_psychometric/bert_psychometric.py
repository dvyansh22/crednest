from __future__ import annotations

from typing import Any, Dict, List


class PsychometricModel:
    def __init__(self):
        self.risk_thresholds = {"low": 35, "medium": 70}

    def predict(self, quiz_responses: List[Dict[str, Any]]) -> Dict[str, Any]:
        risk_score = 0
        for item in quiz_responses:
            answer = str(item.get("answer", "")).lower()
            if any(word in answer for word in ["always", "very", "often"]):
                risk_score += 12
            elif any(word in answer for word in ["sometimes", "uncertain"]):
                risk_score += 5
            elif any(word in answer for word in ["rarely", "never"]):
                risk_score -= 3
        risk_score = max(0, min(100, risk_score))
        level = "Low" if risk_score < self.risk_thresholds["low"] else "Medium" if risk_score < self.risk_thresholds["medium"] else "High"
        return {"risk_level": level, "risk_score": risk_score, "confidence": 0.8 if level != "High" else 0.65}
