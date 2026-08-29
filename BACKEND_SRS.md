❤️😅# Software Requirements Specification
## CredNest API Gateway (Backend Orchestration Layer)

**Version:** 1.0
**Component:** `backend/api-gateway`
**Stack:** Node.js, Express, PostgreSQL, MongoDB, Redis, Kafka, AWS KMS
**Prepared for:** DevJams 2026 — Team HackyChan, VIT Vellore

---

## 0. Scope Boundary — READ FIRST

**You are building ONLY `backend/api-gateway/`.**

Do not create, edit, or delete any files inside:
- `mobile/` (Flutter app — owned by another team member, already in progress)
- `backend/ml-service/` (ML scoring service — owned by another team member, being built per a separate SRS)

Treat both of the above as **frozen external systems** that you integrate with over HTTP, using only the contracts defined in Section 5 of this document. If a contract seems insufficient, do not modify the other service — instead, note the gap in a `docs/integration-notes.md` file inside `backend/api-gateway/` for the team to resolve manually.

You also do not need to build the Setu AA/GST/DigiLocker sandbox registration — that is already complete. Setu sandbox credentials (`client_id`, `client_secret`, product instance IDs) will be provided via environment variables (see Section 6.2). Your job is to write the integration code that consumes these credentials, not to obtain them.

---

## 1. Introduction

### 1.1 Purpose
This service is the orchestration layer between the Flutter mobile app, the Setu-based AA/GST/DigiLocker integrations, the ML scoring service, and the OCEN loan marketplace. It owns: authentication, consent lifecycle, data-fetch orchestration, score requests, loan application orchestration, and all persistence.

### 1.2 What This Service Does
- Authenticates users (JWT + refresh token rotation)
- Manages per-signal consent records (bank, GST, location, quiz) with expiry and independent revocation
- Calls Setu AA APIs to fetch bank statements, ITR, and UPI data after consent is granted
- Calls Setu GST APIs to fetch GSTR-1/GSTR-3B data for MSME borrowers
- Calls Setu DigiLocker APIs for KYC document retrieval
- Assembles fetched data into the exact payload shape the ML service expects, and calls it
- Simulates/integrates the OCEN loan marketplace flow (LoanApplicationRequest → OfferResponse → GrantRequest)
- Persists all users, consents, scores, loan applications, and audit logs
- Exposes a single, stable REST API for the Flutter app to consume

### 1.3 What This Service Does NOT Do
- Does not run any ML models — that's entirely `ml-service`'s job
- Does not render any UI — that's `mobile`'s job
- Does not need to implement AA/GST/DigiLocker sandbox registration — already done on Setu

---

## 2. System Context

```
Flutter App  <--REST/JWT-->  api-gateway  <--REST-->  ml-service (frozen, do not touch)
                                  │
                                  ├── Setu AA APIs (sandbox — credentials provided)
                                  ├── Setu GST APIs (sandbox — credentials provided)
                                  ├── Setu DigiLocker APIs (sandbox — credentials provided)
                                  ├── OCEN lender simulator (build a mock lender endpoint inside this service, OR a standalone script — team decision, default to mock router inside api-gateway for MVP)
                                  ├── PostgreSQL (structured: users, consents, scores, loans)
                                  ├── MongoDB (unstructured: behavioral event logs)
                                  ├── Redis (caching, session/rate-limit state)
                                  └── Kafka (async events: AA refresh jobs, NPA monitoring triggers)
```

---

## 3. Functional Requirements

### FR-1: Authentication
**Routes:** `POST /v1/auth/register`, `POST /v1/auth/login`, `POST /v1/auth/refresh`, `POST /v1/auth/logout`
- JWT access token (short-lived, ~15 min) + refresh token (long-lived, rotated on use, stored hashed in Postgres)
- Passwords/OTP-based login acceptable for MVP — use OTP-over-mobile stub (log OTP to console in sandbox mode, no real SMS provider needed for demo)

### FR-2: DigiLocker Onboarding
**Routes:**
- `POST /v1/onboarding/digilocker/initiate` → calls Setu DigiLocker "create request" API, returns redirect URL to Flutter
- `GET /v1/onboarding/digilocker/status/:requestId` → polls Setu for consent status
- `POST /v1/onboarding/digilocker/callback` → webhook Setu redirects to; stores KYC result (name, masked Aadhaar, PAN) in Postgres

### FR-3: Consent Management
**Routes:**
- `POST /v1/consent` → create a per-signal consent record `{ signal_type: "bank" | "gst" | "location" | "quiz", expiry_days: 30|90|180 }`
- `GET /v1/consent/:userId` → list all active/expired consents
- `DELETE /v1/consent/:consentId` → revoke a signal independently, immediate effect
- Middleware `consent.middleware.js` must block any downstream data-fetch route if the relevant consent is missing, expired, or revoked

**Data model (Postgres `consents` table):**
```
id, user_id, signal_type, status (active/revoked/expired), granted_at, expires_at, consent_artifact_id (Setu's AA consent handle)
```

### FR-4: Account Aggregator Data Fetch
**Routes:**
- `POST /v1/aa/consent/initiate` → calls Setu AA consent API, returns consent handle + AA app redirect URL
- `POST /v1/aa/webhook/consent-notification` → Setu webhook on consent approval/rejection
- `POST /v1/aa/fetch` → after consent approved, calls Setu AA data-fetch API for FI types (bank statements, ITR, UPI); stores raw response encrypted in the consent vault (S3-style storage — use local encrypted disk storage or MinIO for hackathon if AWS S3 isn't set up); stores a reference pointer in Postgres, not raw data
- `POST /v1/aa/refresh/:userId` → triggers a re-fetch for NPA monitoring (called by a scheduled Kafka job, see FR-9)

### FR-5: GST Data Fetch (MSME borrowers only)
**Routes:**
- `POST /v1/gst/verify` → GSTIN existence/status check (gate before further GST scoring)
- `POST /v1/gst/fetch` → calls Setu GST integration for GSTR-3B (and GSTR-1 if available in sandbox) for the requested period range
- Only invoked when `borrower_type == "msme"`

### FR-6: Scoring Orchestration
**Route:** `POST /v1/score/generate`
**Logic:**
1. Verify all required consents are active (bank always; GST only if MSME; quiz always)
2. Pull the already-fetched AA/GST data from storage
3. Pull psychometric quiz responses from Postgres
4. Assemble the exact request payload the ML service's `POST /v1/score` endpoint expects (see Section 5.1 — this contract is frozen, do not alter field names)
5. Call `ml-service`, store the returned score object in Postgres (`scores` table), return it to the Flutter app
6. If `ml-service` is unreachable or still being built, **build a mock response matching the exact same schema** behind a feature flag (`USE_MOCK_ML_SERVICE=true` in `.env`) so the rest of the pipeline (loan flow, ledger, etc.) can be developed and demoed independently

### FR-7: Psychometric Quiz
**Routes:**
- `GET /v1/quiz/questions` → returns the 12-question set (seed data, static JSON is fine)
- `POST /v1/quiz/submit` → stores responses in Postgres, to be read by FR-6

### FR-8: OCEN Loan Marketplace
**Routes:**
- `POST /v1/loans/apply` → builds an OCEN-format `LoanApplicationRequest` JSON from the borrower's score object, broadcasts to registered "lenders"
- For hackathon MVP: implement a **mock lender module** (`src/services/ocen-client/mock-lenders.js`) that returns 2–4 randomized `OfferResponse` objects (varying interest rate, tenure, amount) following the real OCEN schema fields
- `GET /v1/loans/offers/:applicationId` → returns aggregated, ranked offers
- `POST /v1/loans/select` → borrower picks an offer, triggers `GrantRequest` (mocked), returns a disbursement confirmation object
- `POST /v1/loans/:loanId/repay` → records a repayment event (used to drive FR-10 micro-ladder graduation)

### FR-9: NPA Early Warning Trigger (Job, not user-facing route)
**Module:** `src/jobs/npa-monitor.job.js`
- Kafka consumer/scheduled job that periodically calls `POST /v1/aa/refresh/:userId` for active borrowers, then re-calls `ml-service`'s NPA endpoint (or the unified `/v1/score` if NPA is bundled into the ensemble per the ML SRS) and stores/flags alerts

### FR-10: Micro-Ladder Auto-Graduation
**Logic (in `src/services/loan-ladder.service.js`):**
- On successful full repayment of a loan, automatically trigger a new `POST /v1/loans/apply` at a higher ladder tier (e.g., ₹10,000 → ₹25,000) using the borrower's latest score
- No new consent/document upload required if existing consents are still valid

### FR-11: Data Benefit Ledger
**Route:** `GET /v1/ledger/:userId`
- Returns the `signal_contributions` array from the borrower's most recent score object (already provided by `ml-service`'s response — this route just formats/returns stored data, no new computation)

### FR-12: Audit Logging
- Every consent grant/revoke, every AA/GST/DigiLocker data access, every score generation, and every lender query must be written to an **append-only** Mongo collection `audit_logs` with `{ timestamp, user_id, action, resource, metadata }`

---

## 4. Non-Functional Requirements

| Category | Requirement |
|---|---|
| Security | JWT + refresh rotation; encrypt raw AA/GST payloads at rest using AWS KMS or a local equivalent (e.g., `crypto` module with a rotated key for hackathon scope); never log raw PII |
| Performance | End-to-end `/v1/score/generate` should complete within the ~15-minute total pipeline budget described in the product deck; individual gateway calls should not add more than a few seconds of overhead beyond the ML service's own latency |
| Reliability | All external calls (Setu, ml-service, mock OCEN) must have timeout + retry-once logic; failures must return clear error codes to Flutter, never hang |
| Consent enforcement | No data-fetch route may execute without checking `consent.middleware.js` first — this is a hard rule, not a suggestion |
| Environment separation | All Setu credentials, ML service URL, and feature flags must come from `.env` — never hardcoded |

---

## 5. Frozen External Contracts (DO NOT MODIFY THE OTHER SERVICES — INTEGRATE AGAINST THESE ONLY)

### 5.1 ML Service — `POST /v1/score`
Request and response shapes are defined exactly in `backend/ml-service/SRS.md`, Section 3, FR-10. Read that file before implementing `score.routes.js`. Do not invent new field names — if a field you need doesn't exist in that contract, flag it in `docs/integration-notes.md` instead of guessing.

### 5.2 ML Service — `POST /v1/narration/classify`
Defined in `backend/ml-service/SRS.md`, Section 3, FR-1. Use this if you want narration classification to happen before scoring (optional for gateway — can also be left entirely inside `ml-service`, check with the ML teammate which side owns this call).

### 5.3 Mobile App
The gateway must expose stable, versioned REST routes (`/v1/...`) as listed in Section 3. Do not assume anything about the Flutter app's internal structure — only the request/response JSON shapes matter. If the mobile developer requests a field or route not covered here, add it to the gateway and document it in `docs/api-spec.md`, but never open or edit files under `mobile/`.

---

## 6. Technical Requirements

### 6.1 Directory (already scaffolded — fill in, don't restructure)
```
backend/api-gateway/
├── src/
│   ├── app.js
│   ├── routes/{auth,consent,onboarding,aa,gst,score,ocen,webhooks}.routes.js
│   ├── controllers/
│   ├── middleware/{auth,consent}.middleware.js
│   ├── services/{aa-client, gsp-client, digilocker-client, ocen-client, kms}/
│   ├── jobs/
│   └── config/
├── Dockerfile
├── package.json
└── .env.example
```

### 6.2 Required Environment Variables
```
PORT=4000
DATABASE_URL=postgres://...
MONGO_URL=mongodb://...
REDIS_URL=redis://...
KAFKA_BROKERS=...
JWT_SECRET=...
JWT_REFRESH_SECRET=...

SETU_AA_CLIENT_ID=...
SETU_AA_CLIENT_SECRET=...
SETU_AA_PRODUCT_INSTANCE_ID=...
SETU_GST_CLIENT_ID=...
SETU_GST_CLIENT_SECRET=...
SETU_DIGILOCKER_CLIENT_ID=...
SETU_DIGILOCKER_CLIENT_SECRET=...

ML_SERVICE_URL=http://localhost:8000
USE_MOCK_ML_SERVICE=true

KMS_KEY_ID=... (or local key path for hackathon)
```
Do not commit real values — only `.env.example` with placeholder keys goes into the repo.

### 6.3 Suggested Libraries
- `express`, `jsonwebtoken`, `bcrypt`, `pg` (or `prisma`/`sequelize`), `mongoose`, `ioredis`, `kafkajs`, `axios`, `dotenv`, `joi` or `zod` for request validation

---

## 7. Build Order (recommended sequence for the agent)

1. Scaffold `app.js`, config loading, DB connections (Postgres/Mongo/Redis)
2. Auth (FR-1) — everything else depends on a valid JWT
3. Consent management (FR-3) + middleware — required before any data-fetch route works
4. Setu AA client + routes (FR-4) using the provided sandbox credentials
5. Setu GST client + routes (FR-5)
6. Setu DigiLocker client + routes (FR-2)
7. Score orchestration (FR-6) — build with `USE_MOCK_ML_SERVICE=true` first so this doesn't block on the ML teammate's progress; switch to real integration once `ml-service` exposes `/v1/score`
8. Quiz routes (FR-7)
9. OCEN mock lender + loan flow (FR-8)
10. Micro-ladder (FR-10), Data Benefit Ledger (FR-11), NPA job (FR-9), audit logging (FR-12)

---

## 8. Definition of Done
- All routes in Section 3 implemented and testable via Postman/curl without the Flutter app or ml-service running (using the mock ML flag and Setu sandbox)
- No file outside `backend/api-gateway/` created or modified
- `.env.example` present with all required keys, no real secrets committed
- `docs/integration-notes.md` created if any assumption had to be made about the ML or mobile contract
