import joblib
import numpy as np
import pandas as pd

# 1. Old Statistical Estimator
def old_statistical_predict(values: list[float], sector_tag: str = "general"):
    if not values:
        return {"volatility_band": "stable", "min_emi_floor": 900, "seasonal_signal": 0.0}
    mean_value = sum(values) / len(values)
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
        "mean_value": round(mean_value, 2)
    }

# 2. New LSTM Predictor
from app.models.lstm_seasonal.lstm_seasonal import SeasonalIncomeModel
lstm_model = SeasonalIncomeModel()

# 3. Test Profiles
profiles = {
    "Original Gig Driver (14k/mo flat, 4 weekly payouts of 3.5k)": [14000.0] * 12,
    "Steadier Gig Driver (Gradual growth: 12k to 18k)": [12000 + i*500 for i in range(12)],
    "Seasonal Peak Gig (Festival surge: 14k regular, 35k in Oct/Nov)": [14000, 13500, 14200, 14000, 13800, 14100, 13900, 14300, 14000, 35000, 32000, 14500],
    "Choppy Gig Driver (High variance: alternating 6k and 22k)": [6000, 22000, 7000, 25000, 5000, 21000, 8000, 23000, 6500, 24000, 7500, 20000],
    "Lean-Month Gig Driver (Monsoon dip: 15k dropping to 4k for 3 months)": [15000, 16000, 15500, 15000, 14500, 15000, 4000, 4500, 5000, 15000, 16000, 15500],
}

print("=========================================================================================")
print(f"{'Profile Name':<45} | {'Metric':<16} | {'Old Statistical':<16} | {'New LSTM':<16}")
print("=========================================================================================")

for name, series in profiles.items():
    old_res = old_statistical_predict(series)
    new_res = lstm_model.predict(series)
    
    print(f"{name:<45} | {'volatility_band':<16} | {old_res['volatility_band']:<16} | {new_res['volatility_band']:<16}")
    print(f"{'':<45} | {'min_emi_floor':<16} | {str(old_res['min_emi_floor']):<16} | {str(new_res['min_emi_floor']):<16}")
    print(f"{'':<45} | {'seasonal_signal':<16} | {str(old_res['seasonal_signal']):<16} | {str(new_res['seasonal_signal']):<16}")
    print("-" * 100)
