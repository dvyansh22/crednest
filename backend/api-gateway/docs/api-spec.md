# CredNest API Gateway — Specification

This document details the public REST API endpoints exposed by the CredNest API Gateway.

## Base URL
`http://localhost:4000/v1`

## Authentication
Most endpoints require a JWT access token in the `Authorization` header.
Format: `Authorization: Bearer <token>`

---

## 1. Authentication (FR-1)

### `POST /auth/register`
Register a new borrower.
- **Body:** `{ phone: string(10-15 digits), password: string(min 8), full_name?: string, borrower_type?: "individual" | "msme" }`
- **Response (201):** `{ access_token, refresh_token, user: { ... } }`

### `POST /auth/login`
Login with credentials.
- **Body:** `{ phone: string, password: string }`
- **Response (200):** `{ access_token, refresh_token, user: { ... } }`

### `POST /auth/refresh`
Get a new access token using a refresh token.
- **Body:** `{ refresh_token: string }`
- **Response (200):** `{ access_token }`

---

## 2. Onboarding / DigiLocker (FR-2)

### `POST /onboarding/digilocker/initiate`
Get redirect URL for DigiLocker KYC.
- **Response (200):** `{ requestId: string, redirectUrl: string }`

### `GET /onboarding/digilocker/status/:requestId`
Poll for KYC completion status.
- **Response (200):** `{ requestId, status: "pending" | "approved" | "rejected" }`

---

## 3. Consent Management (FR-3)

### `POST /consent`
Create a consent request for a specific data signal.
- **Body:** `{ signal_type: "bank" | "gst" | "quiz", expiry_days?: 30 | 90 | 180 }`
- **Response (201):** `{ message, consent: { id, signal_type, status, expires_at } }`

### `GET /consent/:userId`
List all consents for a user.
- **Response (200):** `{ user_id, consents: [...] }`

---

## 4. Account Aggregator (AA) Fetch (FR-4)
*Requires active `bank` consent.*

### `POST /aa/consent/initiate`
Initiate AA consent flow to get Setu redirect URL.
- **Body:** `{ fi_types?: string[] }` (Default: `["DEPOSIT"]`)
- **Response (200):** `{ consentHandle, redirectUrl }`

### `POST /aa/fetch`
Trigger fetch of AA data after user approves on Setu.
- **Body:** `{ fi_types?: string[], date_range_from?: ISO8601, date_range_to?: ISO8601 }`
- **Response (200):** `{ message, data_refs: [...] }`

---

## 5. GST Fetch (FR-5)
*Requires active `gst` consent and `borrower_type="msme"`.*

### `POST /gst/verify`
Verify GSTIN status.
- **Body:** `{ gstin: string }`
- **Response (200):** `{ gstin, status, legalName }`

### `POST /gst/fetch`
Fetch GST returns (GSTR1, GSTR3B).
- **Body:** `{ gstin: string, from_period?: string(YYYYMM), to_period?: string(YYYYMM) }`
- **Response (200):** `{ message, summary, data_refs }`

---

## 6. Psychometric Quiz (FR-7)

### `GET /quiz/questions`
Get the 12 psychometric questions (No auth required).
- **Response (200):** `{ total: 12, questions: [ { id, text, options } ] }`

### `POST /quiz/submit`
*Requires active `quiz` consent.*
- **Body:** `{ responses: { "Q01": 3, "Q02": 4, ... } }` (Must contain all 12 questions, answers 1-4).
- **Response (201):** `{ message, quiz_id, score_raw }`

---

## 7. Score Generation (FR-6)
*Requires active `bank` and `quiz` consents. `gst` required if MSME.*

### `POST /score/generate`
Orchestrates data gathering and calls ML service to generate score.
- **Response (200):** 
```json
{
  "score_id": "uuid",
  "score_value": 720,
  "risk_band": "LOW",
  "max_eligible_amount": 100000,
  "is_mock": true,
  "generated_at": "ISO8601"
}
```

---

## 8. OCEN Loan Marketplace (FR-8)

### `POST /loans/apply`
Apply for a loan based on the latest generated score.
- **Body:** `{ amount: number, purpose?: string }`
- **Response (201):** `{ application_id, status, offers_count }`

### `GET /loans/offers/:applicationId`
List available offers from lenders for this application.
- **Response (200):** `{ application_id, offers: [ { offerId, lenderName, loanAmount, interestRate, emiAmount, tenureMonths, ... } ] }`

### `POST /loans/select`
Select an offer and trigger mock disbursement.
- **Body:** `{ application_id: uuid, offer_id: uuid }`
- **Response (200):** `{ message, disbursement: { grantId, status, loanAmount } }`

### `POST /loans/:loanId/repay`
Mock repayment of loan (triggers ladder graduation if fully repaid).
- **Body:** `{ amount: number }`
- **Response (200):** `{ message, loan_status: "active" | "repaid", ladder_upgrade?: { message, next_tier, new_application_id } }`

---

## 9. Data Benefit Ledger (FR-11)

### `GET /ledger/:userId`
Fetch transparent breakdown of score computation.
- **Response (200):**
```json
{
  "user_id": "uuid",
  "score_id": "uuid",
  "score_value": 720,
  "risk_band": "LOW",
  "data_benefit_ledger": [
    { "signal": "bank_statements", "weight": 0.35, "contribution": 252, "percentage": "35.0%" },
    { "signal": "psychometric_quiz", "weight": 0.25, "contribution": 180, "percentage": "25.0%" }
  ]
}
```

---

## 10. Webhooks (Setu Integrations)
*No authentication required (production needs payload signing validation).*

### `POST /webhooks/aa/consent`
Receives consent status updates from Setu AA.

### `POST /webhooks/digilocker`
Receives KYC completion callbacks from Setu DigiLocker.
