# Integration Notes — CredNest API Gateway

**Created:** 2026-08-29
**Author:** API Gateway implementation agent

---

## ML Service Contract Assumptions

The ML service SRS (`backend/ml-service/SRS.md`) was empty at time of implementation. The following contract was designed based on descriptions in the API Gateway SRS (§5.1, §5.2, §3 FR-6, FR-11).

### POST /v1/score — Request Payload (assumed)

```json
{
  "user_id": "uuid",
  "borrower_type": "individual | msme",
  "bank_data": [
    {
      "fipID": "string",
      "accounts": [
        {
          "maskedAccNumber": "string",
          "fiType": "DEPOSIT",
          "data": {
            "summary": { "currentBalance": 45000, "avgMonthlyBalance": 38000 },
            "transactions": [
              { "txnId": "string", "type": "CREDIT|DEBIT", "amount": 5000, "narration": "string", "valueDate": "ISO8601" }
            ]
          }
        }
      ]
    }
  ],
  "gst_data": {
    "gstin": "string",
    "GSTR3B": { "totalTaxLiability": 125000, "totalTaxPaid": 120000, "avgMonthlyTurnover": 850000, "filingCompliance": 0.9 },
    "GSTR1": { "totalInvoiceValue": 10200000, "invoiceCount": 84 }
  },
  "psychometric": {
    "responses": { "Q01": 3, "Q02": 4 },
    "score_raw": 75.0
  },
  "kyc_verified": true
}
```

### POST /v1/score — Response Payload (assumed)

```json
{
  "score_id": "string",
  "user_id": "uuid",
  "score_value": 680,
  "risk_band": "LOW | MEDIUM | HIGH",
  "max_eligible_amount": 50000,
  "confidence": 0.82,
  "signal_contributions": [
    { "signal": "bank_statements",   "weight": 0.35, "contribution": 238 },
    { "signal": "gst_data",          "weight": 0.20, "contribution": 136 },
    { "signal": "psychometric_quiz", "weight": 0.25, "contribution": 170 },
    { "signal": "upi_behavior",      "weight": 0.20, "contribution": 136 }
  ],
  "npa_probability": 0.12,
  "explanation": "string",
  "generated_at": "ISO8601"
}
```

**Action required:** ML teammate must confirm or correct these field names. If the actual `ml-service` exposes a different schema, update `src/services/ml-client/index.js` accordingly — field names in the mock match the assumed schema above.

---

## POST /v1/narration/classify (Optional)

API Gateway SRS §5.2 mentions this endpoint. Based on context it appears to classify bank narrations into spending categories before scoring. The gateway does **not** currently call this endpoint — narration classification is assumed to happen inside `ml-service` as part of its own preprocessing. If the ML teammate wants the gateway to call this, document the request/response shape here and update `src/services/ml-client/index.js`.

---

## Setu AA Encryption

The Setu AA response uses encrypted FI data (FIP encrypts with the FIU's public key using ECDH Curve25519). For hackathon scope, the `aa-client` mock bypasses this decryption. When real sandbox credentials are available, the AA client will need to implement the full AA decryption flow per ReBIT AA spec. Flag this with the team before production testing.

---

## OCEN Schema

The OCEN `LoanApplicationRequest` and `OfferResponse` schemas used in `src/services/ocen-client/mock-lenders.js` are simplified versions based on publicly available OCEN 2.0 documentation. Key fields included: `loanAmount`, `currency`, `interestRate`, `interestType`, `repaymentFrequency`, `tenureMonths`, `emiAmount`, `processingFee`, `totalRepayable`, `disbursalMode`. If the team has access to formal OCEN sandbox credentials, update the lender module accordingly.

---

## Vault Storage

Raw AA/GST data is stored as AES-256-GCM encrypted files in `./vault_storage/` (configurable via `LOCAL_STORAGE_PATH`). For production, migrate this to AWS S3 with server-side encryption or MinIO. The vault interface (`src/services/vault/index.js`) uses a simple `store(data) → key` / `retrieve(key) → data` API that can be swapped to an S3 client without changing any callers.

---

## Kafka Usage

For hackathon scope, the NPA monitor runs as a `setInterval` job every 6 hours rather than as a Kafka consumer. If the team wants to switch to a proper Kafka-driven job, `src/config/kafka.js` already exports `createConsumer()` — use it in `src/jobs/npa-monitor.job.js` to subscribe to a `npa.refresh` topic.
