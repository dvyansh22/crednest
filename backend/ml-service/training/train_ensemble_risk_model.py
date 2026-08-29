"""Train and report the production four-model alternative-credit ensemble."""
from __future__ import annotations

import json
from pathlib import Path

import pandas as pd

from app.models.ensemble_scorer import EnsembleScorer
from build_features import build_person_feature_table


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "data" / "dataset"
METRICS_PATH = PROJECT_ROOT / "app" / "models" / "alt_credit_ensemble_metrics.json"
RESULT_PATH = PROJECT_ROOT / "app" / "models" / "alt_credit_ensemble_results.csv"


def main() -> pd.DataFrame:
    feature_table = build_person_feature_table()
    bank_df = pd.read_csv(DATA_DIR / "bank_transactions.csv")
    psych_df = pd.read_csv(DATA_DIR / "psychometric_responses.csv")
    scorer = EnsembleScorer()
    result = scorer.fit(feature_table, bank_df, psych_df)
    result.to_csv(RESULT_PATH, index=False)
    tier_counts = result["tier"].value_counts().reindex(["P1", "P2", "P3", "P4"], fill_value=0)
    metrics = {
        "weights": scorer.weights,
        "tier_distribution": {key: int(value) for key, value in tier_counts.items()},
        "quantile_thresholds": [float(value) for value in scorer.quantile_thresholds],
    }
    METRICS_PATH.write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    print("=== ENSEMBLE RISK TIER DISTRIBUTION ===")
    print(tier_counts.to_string())
    print("\n=== MIXED SAMPLE (seed=42) ===")
    sample = result.groupby("tier", group_keys=False).apply(lambda group: group.sample(min(3, len(group)), random_state=42), include_groups=False)
    print(sample[["final_risk_score", "tier"]].sort_values("final_risk_score").to_string())
    return result


if __name__ == "__main__":
    main()
