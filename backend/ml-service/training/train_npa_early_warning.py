import pandas as pd
import xgboost as xgb
import joblib
from pathlib import Path
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, roc_auc_score, classification_report

def train_npa_model():
    print("Step 1: Loading synthetic NPA trajectories...")
    data_path = Path(__file__).resolve().parents[1] / "data" / "dataset" / "npa_trajectories.csv"
    
    if not data_path.exists():
        raise FileNotFoundError(f"Missing {data_path}")
        
    df = pd.read_csv(data_path)
    
    feature_cols = [f"salary_gap_m{i}" for i in range(1, 7)] + [f"gst_gap_m{i}" for i in range(1, 7)]
    X = df[feature_cols]
    y = df["default_outcome"]
    
    print(f"Total samples: {len(X)}, Defaults: {y.sum()} ({(y.sum()/len(y))*100:.1f}%)")
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.15, random_state=42, stratify=y)
    
    print("Step 2: Training XGBoost Classifier...")
    model = xgb.XGBClassifier(
        n_estimators=100,
        max_depth=4,
        learning_rate=0.05,
        subsample=0.8,
        colsample_bytree=0.8,
        objective="binary:logistic",
        random_state=42,
        eval_metric="auc"
    )
    
    model.fit(
        X_train, y_train,
        eval_set=[(X_test, y_test)],
        verbose=10
    )
    
    print("\nStep 3: Validating Model...")
    y_pred = model.predict(X_test)
    y_prob = model.predict_proba(X_test)[:, 1]
    
    acc = accuracy_score(y_test, y_pred)
    auc = roc_auc_score(y_test, y_prob)
    
    print(f"Validation Accuracy: {acc:.4f}")
    print(f"Validation AUC-ROC:  {auc:.4f}")
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred))
    
    print("Feature Importances:")
    importances = sorted(zip(feature_cols, model.feature_importances_), key=lambda x: x[1], reverse=True)
    for feat, imp in importances[:5]:
        print(f"  {feat}: {imp:.4f}")
        
    out_path = Path(__file__).resolve().parents[1] / "app" / "models" / "npa_early_warning_xgboost.joblib"
    joblib.dump(model, out_path)
    print(f"\nStep 4: Model saved successfully to {out_path}")

if __name__ == "__main__":
    train_npa_model()
