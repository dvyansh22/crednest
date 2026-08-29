# Software Requirements Specification
## CredNest ML Scoring Service

**Version:** 1.0
**Component:** `backend/ml-service`
**Stack:** Python 3.11, FastAPI, XGBoost, TensorFlow, HuggingFace Transformers (BERT)
**Prepared for:** DevJams 2026 — Team HackyChan, VIT Vellore

---

## 1. Introduction

### 1.1 Purpose
This document specifies the functional and non-functional requirements for the CredNest ML Scoring Service — the component responsible for converting behavioral, financial, and psychometric signals into a unified creditworthiness score. It is consumed exclusively by the `api-gateway` service over internal REST calls; it is never exposed directly to the Flutter client.

### 1.2 Scope
The ML service:
- Ingests pre-fetched AA bank statement data, GST filing data, psychometric quiz responses, and on-device federated gradient updates (relayed by the gateway).
- Runs five independent models (XGBoost, BERT, LSTM, Federated TF Lite aggregator, NPA Early Warning).
- Produces an ensemble output: numeric score (0–850), confidence band, stress profile, and a plain-language character narrative.
- Does NOT handle consent management, AA/GSP/DigiLocker API calls, or OCEN communication — those remain in `api-gateway`.
- Does NOT store raw personal data long-term; it operates on data passed per-request and persists only derived features/scores.

### 1.3 Definitions
| Term | Meaning |
|---|---|
| FI Data | Financial Information pulled via Account Aggregator (bank statements, ITR) |
| GSTR-1 / GSTR-3B | GST invoice-level / summary returns |
| Ensemble Score | Final weighted output of all five models |
| Stress Profile | Score recalculated under adverse income scenarios |
| Narration Parsing | Classifying bank transaction narration strings into gig-platform income sources |

### 1.4 Intended Audience
ML engineers and backend engineers on the team implementing and integrating this service during the hackathon build.

---

## 2. Overall Description

### 2.1 System Context
```
Flutter App → api-gateway (Node/Express) → ml-service (FastAPI) → Response → api-gateway → Flutter App
                     │
                     ├── aa-client (fetches raw statements before calling ml-service)
                     └── gsp-client (fetches GST data before calling ml-service)
```
The gateway is responsible for assembling the request payload (already-fetched AA/GST JSON) and forwarding it to `ml-service`. The ML service is stateless per request except for model artifacts loaded at startup.

### 2.2 Assumptions and Constraints
- Raw AA/GST data arrives already fetched — this service does not call external regulatory APIs.
- For hackathon scope, models are trained on public proxy datasets plus a synthetic dataset simulating Indian gig/MSME income patterns.
- On-device federated inference (TF Lite) runs in the Flutter app itself; this service only receives aggregated gradient deltas, not raw device data.
- Single-region deployment for MVP; no multi-tenant isolation required yet.

---

## 3. Functional Requirements

### FR-1: Narration Classification Endpoint
**Route:** `POST /v1/narration/classify`

### FR-2: Feature Engineering — Bank Data
**Module:** `app/features/bank_features.py`

### FR-3: Feature Engineering — GST Data
**Module:** `app/features/gst_features.py`

### FR-4: Cross-Validation Engine
**Module:** `app/features/cross_validation.py`

### FR-5: XGBoost Credit Engine
**Module:** `app/models/xgboost_engine/`

### FR-6: BERT Psychometric Model
**Module:** `app/models/bert_psychometric/`

### FR-7: Seasonal Income LSTM
**Module:** `app/models/lstm_seasonal/`

### FR-8: NPA Early Warning Engine
**Module:** `app/models/npa_early_warning/`

### FR-9: Federated Delta Aggregation
**Module:** `app/models/narration_classifier/` (shared) + a small aggregator

### FR-10: Ensemble Scoring Endpoint
**Route:** `POST /v1/score`

### FR-11: Model Retraining Scripts
**Location:** `app/training/`

---

## 4. Non-Functional Requirements

| Category | Requirement |
|---|---|
| Performance | `/v1/score` must respond within 30 seconds |
| Availability | Single-instance acceptable for hackathon demo |
| Security | No raw PII persisted beyond request lifecycle |
| Explainability | Every score must return signal-level contributions |
| Portability | All models loaded from versioned artifact files |
| Testability | Each feature-engineering and model module must have unit tests |

---

## 5. External Interfaces

### 5.1 Consumed by
- `backend/api-gateway` — internal REST calls only.

### 5.2 Does Not Call
- No direct calls to AA, GSP, DigiLocker, or OCEN endpoints.

---

## 6. Data Requirements

| Dataset | Purpose | Source (hackathon) |
|---|---|---|
| Public credit risk dataset | XGBoost base training | Public download |
| Synthetic gig/MSME income dataset | LSTM seasonal training, narration classifier validation | Generated in-house |
| Synthetic GSTR-1/3B sample set | Cross-validation engine testing | Generated in-house |
| Quiz response bank | BERT/rule-based psychometric scoring | Authored by team |

---

## 7. Directory Reference

```text
backend/ml-service/
├── app/
│   ├── main.py
│   ├── config.py
│   ├── api/routes/{score.py, narration.py}
│   ├── features/{bank_features.py, gst_features.py, cross_validation.py}
│   ├── models/{xgboost_engine, bert_psychometric, lstm_seasonal, npa_early_warning, narration_classifier}/
│   ├── ensemble/score_aggregator.py
│   └── training/{datasets/, train_*.py}
├── requirements.txt
├── Dockerfile
└── SRS.md
```

---

## 8. Open Items for Team Discussion
1. Confirm which models are “fully implemented” vs. “architecturally demonstrated with stub logic”.
2. Decide model weighting scheme for the ensemble aggregator.
3. Finalize synthetic dataset generation parameters.
