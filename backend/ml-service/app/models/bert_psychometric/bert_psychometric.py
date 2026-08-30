from __future__ import annotations

import logging
from typing import Any, Dict, List

logger = logging.getLogger(__name__)

_BERT_PIPELINE = None
_BERT_LOAD_ATTEMPTED = False


def _get_bert_pipeline():
    global _BERT_PIPELINE, _BERT_LOAD_ATTEMPTED
    if _BERT_PIPELINE is None and not _BERT_LOAD_ATTEMPTED:
        _BERT_LOAD_ATTEMPTED = True
        try:
            from transformers import pipeline
            _BERT_PIPELINE = pipeline(
                "sentiment-analysis",
                model="distilbert-base-uncased-finetuned-sst-2-english",
                device=-1  # CPU inference
            )
        except Exception as exc:
            logger.warning(f"DistilBERT failed to initialize, using heuristic fallback: {exc}")
            _BERT_PIPELINE = None
    return _BERT_PIPELINE


class PsychometricModel:
    """
    Psychometric Risk Evaluator.
    Primary Path: Uses DistilBERT (`distilbert-base-uncased-finetuned-sst-2-english`) sentiment analysis
    as a proxy for financial discipline / distress attitude on text quiz answers, combined with deterministic
    cross-question consistency validation.
    Note: DistilBERT is a sentiment classifier used as a proxy for risk attitude, not a purpose-built loan default model.
    Fallback Path: Rule-based keyword matching and contradiction checks if transformer runtime is unavailable.
    """

    def __init__(self):
        self.risk_thresholds = {"low": 35, "medium": 70}

    def predict(self, quiz_responses: List[Dict[str, Any]]) -> Dict[str, Any]:
        if not quiz_responses:
            return {"risk_level": "Low", "risk_score": 0, "confidence": 0.8, "model_used": "empty_default"}

        responses_by_id = {item.get("question_id"): item.get("answer") for item in quiz_responses}
        classifier = _get_bert_pipeline()

        if classifier is not None:
            try:
                return self._predict_bert(quiz_responses, responses_by_id, classifier)
            except Exception as exc:
                logger.warning(f"DistilBERT inference error, falling back to heuristic: {exc}")

        return self._predict_heuristic(quiz_responses, responses_by_id)

    def _predict_bert(self, quiz_responses: List[Dict[str, Any]], responses_by_id: Dict[str, Any], classifier) -> Dict[str, Any]:
        risk_score = 0
        text_answers = []

        for item in quiz_responses:
            ans_str = str(item.get("answer", "")).strip()
            # If answer contains alphabetic text (not just single numeric score)
            if any(c.isalpha() for c in ans_str) and len(ans_str) > 2:
                text_answers.append(ans_str)

        if text_answers:
            # Run batch sentiment classification with DistilBERT
            results = classifier(text_answers)
            for res in results:
                label = res.get("label", "").upper()
                score = float(res.get("score", 0.5))
                if label == "NEGATIVE":
                    # Negative sentiment / distress / panic language increases risk score
                    risk_score += int(score * 12)
                elif label == "POSITIVE":
                    # Disciplined / positive sentiment reduces risk score
                    risk_score -= int(score * 6)

        # Cross-Question Consistency Checks
        # Q03 (tracking frequency) vs Q11 (financial records)
        q3 = self._safe_int(responses_by_id.get("Q03"))
        q11 = self._safe_int(responses_by_id.get("Q11"))
        if q3 and q11:
            if (q3 <= 2 and q11 == 4) or (q3 == 4 and q11 == 1):
                risk_score += 20  # Flag contradictory answers

        # Q02 (repayment priority) vs Q07 (missed deadlines)
        q2 = self._safe_int(responses_by_id.get("Q02"))
        q7 = self._safe_int(responses_by_id.get("Q07"))
        if q2 and q7:
            if q2 == 4 and q7 <= 2:
                risk_score += 20

        risk_score = max(0, min(100, risk_score))
        level = "Low" if risk_score < self.risk_thresholds["low"] else "Medium" if risk_score < self.risk_thresholds["medium"] else "High"
        return {"risk_level": level, "risk_score": risk_score, "confidence": 0.85 if level != "High" else 0.70, "model_used": "distilbert_sst2"}

    def _predict_heuristic(self, quiz_responses: List[Dict[str, Any]], responses_by_id: Dict[str, Any]) -> Dict[str, Any]:
        risk_score = 0
        for item in quiz_responses:
            answer = str(item.get("answer", "")).lower()
            if any(word in answer for word in ["always", "very", "often", "panic", "unpredictable", "never track"]):
                risk_score += 10
            elif any(word in answer for word in ["sometimes", "uncertain", "occasionally"]):
                risk_score += 5
            elif any(word in answer for word in ["rarely", "never", "strict", "weekly"]):
                risk_score -= 3

        q3 = self._safe_int(responses_by_id.get("Q03"))
        q11 = self._safe_int(responses_by_id.get("Q11"))
        if q3 and q11:
            if (q3 <= 2 and q11 == 4) or (q3 == 4 and q11 == 1):
                risk_score += 20

        q2 = self._safe_int(responses_by_id.get("Q02"))
        q7 = self._safe_int(responses_by_id.get("Q07"))
        if q2 and q7:
            if q2 == 4 and q7 <= 2:
                risk_score += 20

        risk_score = max(0, min(100, risk_score))
        level = "Low" if risk_score < self.risk_thresholds["low"] else "Medium" if risk_score < self.risk_thresholds["medium"] else "High"
        return {"risk_level": level, "risk_score": risk_score, "confidence": 0.8 if level != "High" else 0.65, "model_used": "heuristic_fallback"}

    @staticmethod
    def _safe_int(value: Any) -> int:
        try:
            return int(value)
        except (TypeError, ValueError):
            return 0
