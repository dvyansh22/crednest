from __future__ import annotations

import json
import os
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
from xgboost import XGBClassifier

import tensorflow as tf
from tensorflow.keras import layers, models

from build_features import build_person_feature_table, SEQUENCE_PATH, DATA_DIR


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODEL_PATH = PROJECT_ROOT / "app" / "models" / "alt_credit_ensemble.joblib"
LEGACY_MODEL_PATH = PROJECT_ROOT / "app" / "models" / "alt_credit_unsupervised.joblib"
FEATURE_TABLE_PATH = PROJECT_ROOT / "app" / "models" / "alt_credit_feature_table.csv"


def compute_composite_risk_index(df: pd.DataFrame) -> pd.Series:
    """Explainable composite baseline index computed across engineered alternative credit features."""
    weights = {
        "late_bill_payment_rate": 0.24,
        "avg_days_late": 0.18,
        "spending_volatility": 0.12,
        "spending_to_income_ratio": 0.10,
        "income_regularity": 0.10,
        "gig_income_consistency": 0.08,
        "upi_failed_rate": 0.06,
        "p2p_to_p2m_ratio": 0.04,
        "gst_on_time_rate": 0.04,
        "gst_avg_days_late": 0.02,
        "gst_turnover_trend": 0.02,
        "psychometric_discipline_score": 0.06,
        "psychometric_score_variance": 0.02,
        "avg_response_time_seconds": 0.02,
    }

    has_gig = df.get("has_gig_income", pd.Series(1.0, index=df.index)).astype(float)
    has_inc = df.get("has_income", pd.Series(1.0, index=df.index)).astype(float)

    series_list = []
    for col, weight in weights.items():
        if col not in df.columns:
            continue
        values = pd.Series(df[col].astype(float).fillna(0.0), index=df.index)
        if col == "gig_income_consistency":
            normalized = np.where(has_gig > 0, 1.0 - values.clip(0, 1), 0.0)
        elif col == "income_regularity":
            normalized = np.where(has_inc > 0, 1.0 - values.clip(0, 1), 0.5)
        elif col in {"gst_on_time_rate", "psychometric_discipline_score"}:
            normalized = (1.0 - values.clip(0, 1)).fillna(0.0)
        elif col in {"late_bill_payment_rate", "avg_days_late", "spending_volatility", "spending_to_income_ratio", "upi_failed_rate", "p2p_to_p2m_ratio", "gst_avg_days_late", "psychometric_score_variance"}:
            max_value = values.max() if not values.empty else 0.0
            scaled = values / max_value if max_value > 0 else pd.Series(0.0, index=values.index)
            normalized = np.minimum(scaled.clip(0, 1), 1.0).fillna(0.0)
        elif col == "gst_turnover_trend":
            normalized = np.abs(values).clip(0, 1)
        else:
            max_value = values.max() if not values.empty else 0.0
            scaled = values / max_value if max_value > 0 else pd.Series(0.0, index=values.index)
            normalized = np.minimum(scaled.clip(0, 1), 1.0).fillna(0.0)

        series_list.append(pd.Series(normalized * weight, index=df.index, name=col))

    if not series_list:
        return pd.Series(0.0, index=df.index)

    score = pd.concat(series_list, axis=1).sum(axis=1)
    return score.clip(0.0, 1.0)


def build_trend_early_warning_flag(bank_df: pd.DataFrame, person_ids: list[str]) -> np.ndarray:
    """Rule-based 3m vs 9m trend early warning flag comparing worsening late payments & volatility."""
    if bank_df.empty:
        return np.zeros(len(person_ids), dtype=float)

    df = bank_df.copy()
    df["month"] = df["date"].astype(str).str.slice(0, 7)
    months = sorted(df["month"].unique())
    if len(months) < 6:
        return np.zeros(len(person_ids), dtype=float)

    recent_3m = months[-3:]
    earlier_9m = months[:-3]

    df_spend = df[df["type"].astype(str).str.lower() == "debit"]
    late_mask = df_spend["narration"].fillna("").astype(str).str.lower().str.contains("late|emi|bill|payment|credit card|overdue|penalty")

    recent_late = df_spend[late_mask & df_spend["month"].isin(recent_3m)].groupby("person_id").size()
    recent_tot = df_spend[df_spend["month"].isin(recent_3m)].groupby("person_id").size()
    recent_rate = (recent_late / recent_tot).fillna(0.0)

    earlier_late = df_spend[late_mask & df_spend["month"].isin(earlier_9m)].groupby("person_id").size()
    earlier_tot = df_spend[df_spend["month"].isin(earlier_9m)].groupby("person_id").size()
    earlier_rate = (earlier_late / earlier_tot).fillna(0.0)

    res_df = pd.DataFrame({"person_id": person_ids}).set_index("person_id")
    r_rate = recent_rate.reindex(res_df.index, fill_value=0.0)
    e_rate = earlier_rate.reindex(res_df.index, fill_value=0.0)

    flag = ((r_rate > 1.3 * e_rate) & (r_rate > 0.05)) | (r_rate > 0.15)
    return flag.astype(float).to_numpy()


def create_real_lstm_autoencoder(input_timesteps: int = 12, input_channels: int = 3) -> models.Model:
    """Build real TensorFlow/Keras LSTM Autoencoder architecture."""
    model = models.Sequential([
        layers.Input(shape=(input_timesteps, input_channels), name="input_12m_series"),
        layers.LSTM(16, return_sequences=True, name="lstm_encoder"),
        layers.LSTM(8, return_sequences=False, name="lstm_bottleneck_latent"),
        layers.RepeatVector(input_timesteps, name="repeat_temporal_vector"),
        layers.LSTM(16, return_sequences=True, name="lstm_decoder"),
        layers.TimeDistributed(layers.Dense(input_channels), name="time_distributed_dense"),
    ], name="CreditDNA_Real_LSTM_Autoencoder")

    model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=0.005), loss="mse")
    return model


def train_lstm_autoencoder(
    sequences: np.ndarray, epochs: int = 8, batch_size: int = 64
) -> tuple[models.Model, np.ndarray, np.ndarray, np.ndarray]:
    """Train real Keras LSTM Autoencoder on 12-month series and compute reconstruction error."""
    seq_log = np.log1p(np.maximum(sequences, 0.0))
    mean = seq_log.mean(axis=(0, 1), keepdims=True)
    std = seq_log.std(axis=(0, 1), keepdims=True)
    std[std < 1e-6] = 1.0
    normalized = (seq_log - mean) / std

    model = create_real_lstm_autoencoder(input_timesteps=12, input_channels=3)
    model.fit(normalized, normalized, epochs=epochs, batch_size=batch_size, verbose=0, shuffle=True)

    reconstructed = model.predict(normalized, batch_size=batch_size, verbose=0)
    errors = np.mean((reconstructed - normalized) ** 2, axis=(1, 2))
    lstm_risk = (errors - errors.min()) / max((errors.max() - errors.min()), 1e-6)
    return model, lstm_risk, mean, std


def main() -> None:
    print("Step 1: Loading feature table and building 12-month sequence tensor...")
    if FEATURE_TABLE_PATH.exists():
        feature_table = pd.read_csv(FEATURE_TABLE_PATH)
    else:
        feature_table = build_person_feature_table()

    person_ids = feature_table["person_id"].tolist()
    model_columns = [col for col in feature_table.columns if col not in {"person_id", "final_risk_score", "tier"}]
    X = feature_table[model_columns].fillna(0.0).astype(float)

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    print("\nStep 2: Fitting Isolation Forest (unsupervised anomaly detection)...")
    iso = IsolationForest(contamination=0.11, random_state=42, n_estimators=300)
    iso.fit(X_scaled)
    anomaly_score = -iso.score_samples(X_scaled)
    anomaly_norm = (anomaly_score - anomaly_score.min()) / max((anomaly_score.max() - anomaly_score.min()), 1e-6)

    print("\nStep 3: Creating 30% pseudo-labeled dataset (top 15% safest + top 15% riskiest)...")
    p15_safe = np.quantile(anomaly_norm, 0.15)
    p15_risky = np.quantile(anomaly_norm, 0.85)

    safe_mask = anomaly_norm <= p15_safe
    risky_mask = anomaly_norm >= p15_risky
    pseudo_mask = safe_mask | risky_mask

    X_pseudo = X[pseudo_mask]
    y_pseudo = np.zeros(len(X_pseudo), dtype=int)
    y_pseudo[risky_mask[pseudo_mask]] = 1

    print(f"Pseudo-labeled subset: {len(X_pseudo)} people ({safe_mask.sum()} safe P1/P2, {risky_mask.sum()} risky P3/P4).")

    print("\nStep 4: Training XGBoost classifier on pseudo-labeled subset...")
    xgb = XGBClassifier(
        objective="binary:logistic",
        n_estimators=300,
        max_depth=5,
        learning_rate=0.05,
        subsample=0.9,
        colsample_bytree=0.9,
        eval_metric="logloss",
        tree_method="exact",
        random_state=42,
    )
    X_pseudo_arr = np.ascontiguousarray(X_pseudo.values, dtype=np.float32)
    y_pseudo_arr = np.ascontiguousarray(y_pseudo, dtype=np.float32)
    xgb.fit(X_pseudo_arr, y_pseudo_arr)
    X_all_arr = np.ascontiguousarray(X.values, dtype=np.float32)
    xgb_prob = xgb.predict_proba(X_all_arr)[:, 1]

    print("\nStep 5: Training Real TensorFlow/Keras LSTM Autoencoder on 12-month sequences...")
    if SEQUENCE_PATH.exists():
        sequences = np.load(SEQUENCE_PATH)
    else:
        bank_path = DATA_DIR / "bank_transactions.csv"
        bank_df = pd.read_csv(bank_path) if bank_path.exists() else pd.DataFrame()
        from build_features import build_12m_sequence_tensor
        sequences = build_12m_sequence_tensor(bank_df, person_ids)

    lstm_model, lstm_risk, lstm_mean, lstm_std = train_lstm_autoencoder(sequences, epochs=8)

    print("\n=== REAL LSTM AUTOENCODER MODEL SUMMARY ===")
    lstm_model.summary()
    print("============================================\n")

    print("Step 6: Calculating 3m vs 9m trend-based early warning flag (Rule-Based)...")
    bank_path = DATA_DIR / "bank_transactions.csv"
    bank_df = pd.read_csv(bank_path, dtype={"person_id": str, "type": str, "narration": str, "amount": float}) if bank_path.exists() else pd.DataFrame()
    trend_flag = build_trend_early_warning_flag(bank_df, person_ids)

    print("\nStep 7: Computing composite index & combining ensemble risk signals...")
    composite_index = compute_composite_risk_index(X).to_numpy()

    final_risk = (
        0.35 * xgb_prob
        + 0.25 * anomaly_norm
        + 0.20 * lstm_risk
        + 0.10 * trend_flag
        + 0.10 * composite_index
    )
    final_risk = np.clip(final_risk, 0.0, 1.0)

    print("\nStep 8: Quantile Tier Assignment (Target: P1 ~11%, P2 ~63%, P3 ~15%, P4 ~11%)...")
    q_thresholds = np.quantile(final_risk, [0.11, 0.74, 0.89])
    tiers = np.array(["P2"] * len(final_risk), dtype=object)
    tiers[final_risk <= q_thresholds[0]] = "P1"
    tiers[(final_risk > q_thresholds[0]) & (final_risk <= q_thresholds[1])] = "P2"
    tiers[(final_risk > q_thresholds[1]) & (final_risk <= q_thresholds[2])] = "P3"
    tiers[final_risk > q_thresholds[2]] = "P4"

    feature_table["final_risk_score"] = final_risk
    feature_table["tier"] = tiers

    tier_counts = feature_table["tier"].value_counts().reindex(["P1", "P2", "P3", "P4"])
    tier_percents = (tier_counts / len(feature_table) * 100).round(2)
    tier_summary = pd.DataFrame({"Count": tier_counts, "Percentage (%)": tier_percents})

    print("\n=== ENSEMBLE RISK TIER DISTRIBUTION ===")
    print(tier_summary.to_string())

    print("\n=== TOP 10 RISKSIEST PEOPLE (CONFIRM NO DUPLICATE IDENTICAL VALUES) ===")
    top_10_riskiest = feature_table.sort_values("final_risk_score", ascending=False).head(10)
    print(top_10_riskiest[["person_id", "tier", "final_risk_score", "income_regularity", "gig_income_consistency", "spending_to_income_ratio", "late_bill_payment_rate", "avg_days_late", "spending_volatility", "psychometric_discipline_score"]].to_string(index=False))

    print("\n=== 10 RANDOM PEOPLE (COMPARISON SAMPLE) ===")
    random_10 = feature_table.sample(n=10, random_state=42)
    print(random_10[["person_id", "tier", "final_risk_score", "income_regularity", "gig_income_consistency", "spending_to_income_ratio", "late_bill_payment_rate", "avg_days_late", "spending_volatility", "psychometric_discipline_score"]].to_string(index=False))

    print("\nStep 9: Saving unified ensemble artifact joblib...")
    artifact = {
        "iso_model": iso,
        "xgb_model": xgb,
        "scaler": scaler,
        "feature_columns": model_columns,
        "quantile_thresholds": q_thresholds.tolist(),
        "tier_quantiles": [0.11, 0.74, 0.89],
        "weights": {
            "xgb_prob": 0.35,
            "anomaly_norm": 0.25,
            "lstm_risk": 0.20,
            "trend_flag": 0.10,
            "composite_index": 0.10,
        },
        "lstm_weights": lstm_model.get_weights(),
        "lstm_mean": lstm_mean,
        "lstm_std": lstm_std,
    }
    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(artifact, MODEL_PATH)
    joblib.dump(artifact, LEGACY_MODEL_PATH)
    print(f"Saved ensemble artifact to {MODEL_PATH}")


if __name__ == "__main__":
    main()
