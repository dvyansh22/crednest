from __future__ import annotations

import os
from pathlib import Path
import joblib
import numpy as np
import pandas as pd
import tensorflow as tf
from tensorflow.keras import layers, models

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "data" / "dataset"
MODEL_PATH = PROJECT_ROOT / "app" / "models" / "seasonal_income_lstm.joblib"


def extract_monthly_inflow_matrix(bank_df: pd.DataFrame) -> tuple[np.ndarray, list[str]]:
    """Extract (N, 12, 1) monthly credit inflow matrix across all persons."""
    df = bank_df.copy()
    df["month"] = df["date"].astype(str).str.slice(0, 7)
    df["amount"] = pd.to_numeric(df["amount"], errors="coerce").fillna(0.0)
    df["type"] = df["type"].astype(str).str.lower()

    credits = df[df["type"] == "credit"]
    all_persons = sorted(df["person_id"].unique())
    all_months = sorted(df["month"].unique())[-12:]
    if len(all_months) < 12:
        all_months = [f"2025-{m:02d}" for m in range(1, 13)]

    grid_idx = pd.MultiIndex.from_product([all_persons, all_months], names=["person_id", "month"])
    monthly_inflows = (
        credits.groupby(["person_id", "month"])["amount"]
        .sum()
        .reindex(grid_idx, fill_value=0.0)
        .unstack("month")
    )
    raw_matrix = monthly_inflows.to_numpy(dtype=np.float32)  # (N, 12)
    return raw_matrix, all_persons


def generate_synthetic_profiles(num_samples_per_type=2000) -> np.ndarray:
    """Generate heavily augmented canonical 12-month profiles (Flat, Growing, Declining, Peak, Choppy)."""
    np.random.seed(42)
    synthetic = []

    for _ in range(num_samples_per_type):
        # 1. Flat Profile (Perfectly Stable)
        base = np.random.uniform(5000, 50000)
        synthetic.append(np.full(12, base, dtype=np.float32))

        # 2. Gradually Growing Profile (Stable trend)
        growth_rate = np.random.uniform(1.02, 1.10)
        start_val = np.random.uniform(5000, 30000)
        seq = [start_val * (growth_rate ** m) for m in range(12)]
        synthetic.append(seq + np.random.normal(0, start_val * 0.02, 12))

        # 3. Gradually Declining Profile (Stable trend)
        decline_rate = np.random.uniform(0.90, 0.98)
        start_val = np.random.uniform(15000, 40000)
        seq = [start_val * (decline_rate ** m) for m in range(12)]
        synthetic.append(seq + np.random.normal(0, start_val * 0.02, 12))

        # 4. Seasonal Peak (Flat then massive jump for 1-2 months)
        base = np.random.uniform(5000, 20000)
        seq = np.full(12, base)
        peak_month = np.random.randint(0, 11)
        seq[peak_month] = base * np.random.uniform(3.0, 6.0)
        if peak_month < 11 and np.random.rand() > 0.5:
            seq[peak_month+1] = base * np.random.uniform(2.0, 4.0)
        synthetic.append(seq + np.random.normal(0, base * 0.05, 12))

        # 5. Choppy / Erratic (High variance month to month)
        base = np.random.uniform(10000, 30000)
        seq = np.random.uniform(base * 0.1, base * 2.5, 12)
        # Drop a few months to zero to simulate job loss / gaps
        for _ in range(np.random.randint(1, 4)):
            seq[np.random.randint(0, 12)] = 0
        synthetic.append(seq)

    return np.array(synthetic, dtype=np.float32)


def compute_heuristic_volatility_labels(inflow_matrix: np.ndarray) -> np.ndarray:
    """Compute statistical heuristic volatility labels (0.0 to 1.0) on 12m monthly inflow series."""
    labels = []
    for row in inflow_matrix:
        mean_val = float(np.mean(row))
        if mean_val <= 0:
            labels.append(1.0)
            continue
        std_val = float(np.std(row))
        cv = std_val / max(mean_val, 1.0)
        diffs = [abs(row[i] - row[i-1]) / max(row[i-1], 1.0) for i in range(1, len(row))]
        avg_diff = float(np.mean(diffs)) if diffs else 0.0
        # Reduced aggressive scaling (from 0.65/0.35 to 0.5/0.2) to map augmented data more smoothly to 0.0-1.0
        volatility = min(1.0, 0.5 * cv + 0.2 * avg_diff)
        labels.append(volatility)
    return np.array(labels, dtype=np.float32)


def apply_per_sequence_scaling(inflow_matrix: np.ndarray) -> np.ndarray:
    """Applies per-sequence mean scaling (X / mean) to preserve coefficient of variation while removing absolute magnitude."""
    X = np.zeros_like(inflow_matrix)
    for i in range(len(inflow_matrix)):
        row = inflow_matrix[i]
        seq_mean = np.mean(row)
        if seq_mean < 1e-6:
            X[i] = 0.0
        else:
            X[i] = row / seq_mean
    return X


def create_seasonal_lstm_model(timesteps: int = 12, features: int = 1) -> models.Model:
    """Lightweight Keras LSTM regressor for 12-month income seasonality estimation."""
    model = models.Sequential([
        layers.Input(shape=(timesteps, features), name="input_12m_inflow"),
        layers.LSTM(16, return_sequences=False, name="lstm_temporal_extractor"),
        layers.Dropout(0.2, name="lstm_dropout"),
        layers.Dense(8, activation="relu", name="dense_hidden"),
        layers.Dropout(0.1, name="dense_dropout"),
        layers.Dense(1, activation="sigmoid", name="volatility_output")
    ], name="Seasonal_Income_LSTM_Regressor")
    model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=0.001), loss="mse")
    return model


def main():
    print("Step 1: Loading bank transactions and extracting 12m inflow sequences...")
    bank_path = DATA_DIR / "bank_transactions.csv"
    if not bank_path.exists():
        raise FileNotFoundError(f"Bank transactions not found at {bank_path}")

    bank_df = pd.read_csv(
        bank_path,
        dtype={"person_id": str, "type": str, "narration": str, "amount": float},
        usecols=["person_id", "date", "type", "amount"],
    )
    raw_matrix, person_ids = extract_monthly_inflow_matrix(bank_df)
    
    print(f"Original dataset: {len(raw_matrix)} sequences.")
    
    print("Step 1.5: Augmenting with diverse synthetic canonical profiles...")
    synthetic_matrix = generate_synthetic_profiles(num_samples_per_type=2000) # 10000 diverse profiles
    
    combined_matrix = np.vstack([raw_matrix, synthetic_matrix])
    print(f"Combined dataset: {len(combined_matrix)} sequences.")

    y = compute_heuristic_volatility_labels(combined_matrix)

    # Label distribution check
    stable = np.sum(y < 0.12)
    moderate = np.sum((y >= 0.12) & (y < 0.25))
    volatile = np.sum(y >= 0.25)
    print(f"Label Distribution -> Stable: {stable}, Moderate: {moderate}, Volatile: {volatile}")

    # Apply per-sequence scaling
    X_scaled = apply_per_sequence_scaling(combined_matrix)
    X = X_scaled[..., np.newaxis]  # (N, 12, 1)

    print("Step 2: Training Keras LSTM Seasonal Regressor...")
    model = create_seasonal_lstm_model(timesteps=12, features=1)
    
    callbacks = [
        tf.keras.callbacks.EarlyStopping(monitor='val_loss', patience=3, restore_best_weights=True)
    ]
    
    history = model.fit(
        X, y, 
        epochs=15, 
        batch_size=64, 
        validation_split=0.15,
        verbose=1, 
        shuffle=True,
        callbacks=callbacks
    )

    test_preds = model.predict(X[:10], verbose=0).flatten()
    print("\nSample predictions vs targets (First 10 original):")
    for true_val, pred_val in zip(y[:10], test_preds):
        print(f"  Target: {true_val:.4f} | Predicted: {pred_val:.4f}")

    print("\nStep 3: Saving artifact to", MODEL_PATH)
    artifact = {
        "weights": model.get_weights(),
        "preprocessing": "per_sequence_min_max_scale",
        "architecture_config": {
            "timesteps": 12,
            "features": 1,
            "hidden_units": 16,
            "dense_units": 8,
            "dropout_lstm": 0.2,
            "dropout_dense": 0.1
        },
        "training_metadata": {
            "dataset": "bank_transactions_augmented",
            "samples": len(X),
            "target_type": "statistical_heuristic_volatility_labels_v2",
        }
    }
    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(artifact, MODEL_PATH)
    print("Successfully trained and saved Seasonal Income LSTM artifact.")


if __name__ == "__main__":
    main()
