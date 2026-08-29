from __future__ import annotations

from typing import Any, Dict, Iterable, List


class SeasonalIncomeModel:
    def __init__(self):
        self.volatility_bands = {"stable": 1.0, "moderate": 1.5, "volatile": 2.0}

    def predict(self, income_series: Iterable[float], sector_tag: str = "general") -> Dict[str, Any]:
        values = [float(value) for value in income_series]
        if not values:
            return {"volatility_band": "stable", "min_emi_floor": 900, "seasonal_signal": 0.0}
        mean_value = sum(values) / len(values)
        variance = sum((value - mean_value) ** 2 for value in values) / len(values)
        volatility = variance ** 0.5 / max(mean_value, 1.0)

        if volatility < 0.12:
            band = "stable"
        elif volatility < 0.25:
            band = "moderate"
        else:
            band = "volatile"

        min_emi_floor = max(900, int(mean_value * 0.08))
        return {
            "volatility_band": band,
            "min_emi_floor": min_emi_floor,
            "seasonal_signal": round(volatility, 4),
            "sector_tag": sector_tag,
        }
