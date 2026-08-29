from __future__ import annotations

import json
from pathlib import Path

import joblib
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from xgboost import XGBClassifier


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "data"
MODEL_DIR = PROJECT_ROOT / "app" / "models"
MODEL_PATH = MODEL_DIR / "credit_risk_xgb.joblib"


def load_data() -> pd.DataFrame:
    internal = pd.read_excel(DATA_DIR / "Internal_Bank_Dataset.xlsx")
    external = pd.read_excel(DATA_DIR / "External_Cibil_Dataset.xlsx")
    merged = internal.merge(external, on="PROSPECTID", how="inner", validate="one_to_one")
    return merged


def clean_dataset(df: pd.DataFrame) -> pd.DataFrame:
    cleaned = df.copy()

    for col in ["PROSPECTID", "Approved_Flag"]:
        if col in cleaned.columns:
            cleaned[col] = cleaned[col].astype(str).str.strip()

    for col in cleaned.columns:
        if cleaned[col].dtype == "object":
            cleaned[col] = cleaned[col].replace(["nan", "NaN", "N/A", "NA", ""], pd.NA)

    target_col = "Approved_Flag"
    if target_col in cleaned.columns:
        cleaned[target_col] = cleaned[target_col].replace({"P1": 0, "P2": 1, "P3": 2, "P4": 3})

    cleaned = cleaned.dropna(subset=[target_col]).copy()

    categorical_candidates = [
        "MARITALSTATUS",
        "EDUCATION",
        "GENDER",
        "last_prod_enq2",
        "first_prod_enq2",
    ]
    for col in categorical_candidates:
        if col in cleaned.columns:
            cleaned[col] = cleaned[col].fillna("Missing").astype(str)

    numeric_cols = [col for col in cleaned.select_dtypes(include=["number"]).columns if col != target_col]
    for col in numeric_cols:
        cleaned[col] = pd.to_numeric(cleaned[col], errors="coerce")
    cleaned[numeric_cols] = cleaned[numeric_cols].fillna(cleaned[numeric_cols].median())

    return cleaned


def make_preprocessor(X: pd.DataFrame):
    categorical_cols = [
        "MARITALSTATUS",
        "EDUCATION",
        "GENDER",
        "last_prod_enq2",
        "first_prod_enq2",
    ]
    numeric_cols = [col for col in X.columns if col not in categorical_cols]

    transformers = []
    if numeric_cols:
        transformers.append(
            (
                "num",
                Pipeline(
                    steps=[
                        ("imputer", SimpleImputer(strategy="median")),
                        ("scaler", StandardScaler()),
                    ]
                ),
                numeric_cols,
            )
        )
    if any(col in X.columns for col in categorical_cols):
        cat_cols = [col for col in categorical_cols if col in X.columns]
        transformers.append(
            (
                "cat",
                Pipeline(
                    steps=[
                        ("imputer", SimpleImputer(strategy="most_frequent")),
                        ("onehot", OneHotEncoder(handle_unknown="ignore", sparse_output=False)),
                    ]
                ),
                cat_cols,
            )
        )

    if not transformers:
        raise ValueError("No usable feature columns found after cleaning.")

    return ColumnTransformer(transformers=transformers, remainder="drop")


def build_model() -> XGBClassifier:
    return XGBClassifier(
        objective="multi:softprob",
        num_class=4,
        n_estimators=500,
        max_depth=6,
        learning_rate=0.05,
        subsample=0.9,
        colsample_bytree=0.9,
        reg_lambda=1.0,
        random_state=42,
        eval_metric="mlogloss",
    )


def main() -> None:
    df = load_data()
    cleaned = clean_dataset(df)

    feature_columns = [col for col in cleaned.columns if col not in ["PROSPECTID", "Approved_Flag"]]
    X = cleaned[feature_columns]
    y = cleaned["Approved_Flag"].astype(int)

    if y.nunique() < 2:
        raise ValueError("Target column does not contain multiple classes after cleaning.")

    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=0.2,
        random_state=42,
        stratify=y,
    )

    preprocessor = make_preprocessor(X_train)
    X_train_processed = preprocessor.fit_transform(X_train)
    X_test_processed = preprocessor.transform(X_test)

    class_counts = y_train.value_counts().sort_index()
    class_weights = {label: (len(y_train) / (len(class_counts) * count)) for label, count in class_counts.items()}
    sample_weights = y_train.map(class_weights).to_numpy()

    model = build_model()
    model.fit(X_train_processed, y_train, sample_weight=sample_weights)

    y_pred = model.predict(X_test_processed)
    accuracy = accuracy_score(y_test, y_pred)
    report = classification_report(y_test, y_pred, digits=4, output_dict=True, labels=[0, 1, 2, 3], target_names=["P1", "P2", "P3", "P4"])
    cm = confusion_matrix(y_test, y_pred, labels=[0, 1, 2, 3])

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    artifact = {
        "model": model,
        "preprocessor": preprocessor,
        "feature_columns": feature_columns,
        "target_mapping": {0: "P1", 1: "P2", 2: "P3", 3: "P4"},
        "metrics": {
            "accuracy": float(accuracy),
            "classification_report": report,
            "confusion_matrix": cm.tolist(),
            "class_distribution": {str(k): int(v) for k, v in class_counts.items()},
        },
    }
    joblib.dump(artifact, MODEL_PATH)

    with open(MODEL_DIR / "credit_risk_xgb_metrics.json", "w", encoding="utf-8") as f:
        json.dump({
            "accuracy": float(accuracy),
            "classification_report": report,
            "confusion_matrix": cm.tolist(),
        }, f, indent=2)

    print("=== Credit Risk XGBoost Training Results ===")
    print(f"Accuracy: {accuracy:.4f}")
    print("\nPer-class metrics:")
    print(classification_report(y_test, y_pred, digits=4, labels=[0, 1, 2, 3], target_names=["P1", "P2", "P3", "P4"]))
    print("\nConfusion matrix:")
    print(cm)


if __name__ == "__main__":
    main()
