from __future__ import annotations

from typing import Dict, Iterable, List

GIG_ENTITY_DICTIONARY = {
    "swiggy": "Swiggy",
    "bundl": "Swiggy",
    "ola": "Ola",
    "uber": "Uber",
    "zomato": "Zomato",
    "blinkit": "Blinkit",
    "amazon seller": "Amazon Seller Services",
    "google": "Google AsiaPacific",
    "bharatpe": "BharatPe",
    "urban company": "Urban Company",
}


class NarrationClassifier:
    def classify(self, text: str) -> str:
        normalized = (text or "").lower()
        for key, value in GIG_ENTITY_DICTIONARY.items():
            if key in normalized:
                return value
        if any(token in normalized for token in ["upi", "neft", "imps", "p2p"]):
            return "Platform Income"
        return "Other Income"

    def classify_batch(self, transactions: Iterable[dict]) -> List[dict]:
        results = []
        for record in transactions:
            narration = str(record.get("narration", ""))
            source = self.classify(narration)
            results.append({
                "date": record.get("date"),
                "source": source,
                "category": "gig_income" if source != "Other Income" else "misc_income",
                "amount": float(record.get("amount", 0) or 0),
            })
        return results


def classify_narration_text(text: str) -> str:
    return NarrationClassifier().classify(text)
