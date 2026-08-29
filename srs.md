# Software Requirements Specification — CreditDNA

**Version:** 1.0
**Platform:** Flutter (Android primary, iOS/macOS secondary)
**Purpose of this document:** This SRS is written to be consumed by an AI coding agent (e.g. Claude Code) as the source of truth for implementation. Each section is scoped, unambiguous, and mapped to the existing folder structure so the agent can locate or create the correct files without additional clarification. Where a decision is still open, it is explicitly marked `[OPEN DECISION]` rather than assumed.

---

## 1. Product Summary

CreditDNA is an AI-driven alternate credit scoring platform for individuals and MSMEs with no formal credit history (no CIBIL score). It converts existing behavioral and financial signals — bank transactions, GST filings, ITR data, UPI patterns, geolocation stability, and a psychometric quiz — into a trusted credit score, then broadcasts the borrower's loan application to multiple lenders via the OCEN protocol so they receive competing offers.

**Core principle:** consent-first, privacy-first, zero dependence on CIBIL.

**Primary users:**
- Borrowers: individuals with no/thin credit file, gig workers, MSME owners
- (Future/out of scope for MVP) Lenders: NBFCs/MFIs consuming the OCEN feed

---

## 2. Scope of This Build

### 2.1 In scope (MVP)
- Flutter mobile app (Android first)
- Real API integrations (no mocked data) for: DigiLocker KYC, RBI Account Aggregator (Setu/Finvu sandbox), GST Suvidha Provider
- Consent management UI and storage
- Psychometric quiz (in-app, no external API)
- Credit score display (score fetched from a backend ML service — backend is a separate repo/service, not built in this Flutter codebase)
- OCEN loan offer marketplace (list + select real or sandbox lender offers)
- Data Benefit Ledger screen (shows which signal contributed how much to the score)
- Dashboard/home screen

### 2.2 Out of scope (MVP)
- Lender-side portal/dashboard
- Admin/back-office tools
- Multi-language localization
- Push notifications (defer to v2)
- On-device federated learning (TF Lite federated inference is a backend/ML concern, not a Flutter UI concern for MVP — Flutter only sends on-device signals like geolocation hash)

### 2.3 Explicit non-goals
- Do not build a CIBIL/bureau integration of any kind.
- Do not build direct gig-platform API integrations (Zomato/Swiggy/Ola) — gig income is derived from AA bank statement narration parsing on the backend.

---

## 3. Tech Stack (authoritative — do not substitute without approval)

| Layer | Choice |
|---|---|
| Frontend framework | Flutter (Dart) |
| State management | flutter_riverpod |
| Routing | go_router |
| HTTP client | dio |
| Secure local storage | flutter_secure_storage |
| Local (non-sensitive) storage | shared_preferences or hive — `[OPEN DECISION]`, default to shared_preferences for MVP |
| Location | geolocator |
| Charts (score gauge, ledger) | fl_chart |
| Env config | flutter_dotenv |
| Backend (separate service, consumed via REST) | Node.js + Express (auth, OCEN webhooks), Python + FastAPI (ML scoring: XGBoost, BERT, LSTM) |
| KYC | DigiLocker SDK/API |
| Account Aggregator | Setu or Finvu AA SDK |
| GST data | GST Suvidha Provider API (Masters India / Cleartax) |
| Encryption | RSA-2048 for data in transit; JWT + refresh rotation for auth |

---

## 4. Architecture Pattern

Feature-first, layered within each feature:

```
lib/features/<feature_name>/
├── data/
│   ├── models/           # raw API request/response models
│   ├── datasources/      # remote/local data source classes (raw API calls)
│   └── repositories/     # repository interface + impl — maps datasource -> domain model, handles errors
├── application/          # Riverpod providers/state notifiers — business logic, no widgets
└── presentation/         # screens and feature-specific widgets
```

Shared code lives in `lib/core/` (network, config, security, storage, utils) and `lib/shared/` (reusable widgets, generic models).

**Agent instruction:** When implementing a feature, always create/modify files in this order: `data/models` → `data/datasources` → `data/repositories` → `application` → `presentation`. Never put HTTP calls directly in a widget or provider — they must go through a datasource + repository.

---

## 5. Features — Detailed Requirements

Each feature below lists: purpose, screens, data needed, API dependency, and acceptance criteria. Folder path is given so the agent maps work directly to `lib/features/<name>/`.

### 5.1 `splash`
- **Purpose:** App entry, check auth token validity, route to onboarding/login/dashboard.
- **Screens:** `splash_screen.dart`
- **Logic:** On launch, check `secure_storage` for a valid JWT. If present and unexpired → route to `dashboard`. If absent → route to `onboarding` (first launch) or `login`.
- **Acceptance criteria:**
    - [ ] App never shows a blank white screen for more than 2s before routing.
    - [ ] Token expiry check happens before any navigation decision.

### 5.2 `onboarding`
- **Purpose:** First-launch explainer of what CreditDNA does and what data it will request.
- **Screens:** `onboarding_screen.dart`
- **Logic:** 3–4 swipeable slides, last slide CTA → `signup_screen`.
- **Acceptance criteria:**
    - [ ] Shown only once (persist a "seen_onboarding" flag locally).
    - [ ] Skippable.

### 5.3 `auth`
- **Purpose:** Signup/login, JWT session management.
- **Screens:** `login_screen.dart`, `signup_screen.dart`
- **Data model:** `user_model.dart` — fields: `id`, `phone`, `email` (optional), `name`, `createdAt`.
- **API dependency:** Backend auth endpoint (Node.js/Express) — `[OPEN DECISION: exact endpoint contract to be provided by backend team]`.
- **Logic:** Phone number + OTP is the expected primary auth method for this user base (many borrowers may not have email). Store JWT + refresh token in `flutter_secure_storage` on success.
- **Acceptance criteria:**
    - [ ] No plaintext token storage — must use secure storage only.
    - [ ] Failed auth shows a clear, non-technical error message.
    - [ ] Token refresh handled transparently via `api_interceptors.dart` — UI never manually refreshes tokens.

### 5.4 `consent`
- **Purpose:** Per-signal consent capture before any data collection. This is a core differentiator — must be visually explicit, not buried in T&Cs.
- **Screens:** `consent_screen.dart`
- **Data model:** `consent_model.dart` — fields: `signalType` (enum: `bankStatement`, `gst`, `itr`, `upi`, `location`, `psychometric`), `granted` (bool), `grantedAt`, `expiresAt`, `revoked` (bool).
- **Logic:** Each signal is an independent toggle. No signal's data collection screen (financial_data, gst, location, psychometric) may be entered unless its corresponding consent is `granted` and not expired/revoked.
- **Acceptance criteria:**
    - [ ] Toggling a signal off after being on must trigger a revoke call and disable that data collection flow immediately.
    - [ ] Consent expiry options: 30/90/180 days, user-selectable per signal.
    - [ ] No signal is pre-toggled "on" by default.

### 5.5 `kyc`
- **Purpose:** Identity verification via DigiLocker (Aadhaar + PAN).
- **Screens:** `kyc_screen.dart`, `kyc_status_screen.dart`
- **Data model:** `kyc_model.dart` — fields: `status` (enum: `notStarted`, `pending`, `verified`, `failed`), `aadhaarLast4`, `panVerified` (bool), `verifiedAt`.
- **API dependency:** DigiLocker Partner API — real sandbox credentials required (see Section 7).
- **Recommended build order:** This is the **first real-API feature to implement** (see Section 8) because DigiLocker's flow is the most standardized (redirect/webview based).
- **Acceptance criteria:**
    - [ ] Uses `webview_flutter` for the DigiLocker consent redirect flow.
    - [ ] Handles user cancellation mid-flow gracefully (return to `kyc_screen` with a retry option, not a crash).
    - [ ] `kyc_status_screen` polls or listens for verification completion and unlocks the next step (`financial_data` or `dashboard`) only on `verified`.

### 5.6 `financial_data` (Account Aggregator)
- **Purpose:** Pull bank statements, ITR, and UPI transaction history via RBI Account Aggregator framework.
- **Screens:** `connect_bank_screen.dart`, `bank_status_screen.dart`, `transaction_summary_screen.dart`
- **Data model:** `transaction_model.dart` — fields: `id`, `date`, `amount`, `narration`, `type` (credit/debit), `balanceAfter`.
- **Datasource:** `aa_remote_datasource.dart` — isolates raw Setu/Finvu SDK/API calls from the repository, since AA has a distinct consent-artifact-based auth flow different from standard OAuth.
- **API dependency:** Setu or Finvu AA sandbox — `[OPEN DECISION: which of the two — confirm with team before building]`.
- **Acceptance criteria:**
    - [ ] Requires `consent.bankStatement == granted` before this feature is reachable.
    - [ ] Raw narration strings are never displayed unprocessed to the score explanation UI — only used for backend classification.
    - [ ] Handles AA consent expiry (30/90/180 days) by prompting re-consent, not silently failing.

### 5.7 `gst`
- **Purpose:** Pull GST filing history for MSME borrowers (GSTR-1, GSTR-3B).
- **Screens:** `connect_gst_screen.dart`
- **Data model:** `gst_model.dart` — fields: `gstin`, `filingStatus`, `lastFiledDate`, `turnoverDeclared`.
- **API dependency:** GST Suvidha Provider (Masters India / Cleartax) — sandbox credentials required.
- **Acceptance criteria:**
    - [ ] Only shown/reachable for users who self-identify as MSME/business owners during signup or profile setup.
    - [ ] Requires `consent.gst == granted`.

### 5.8 `psychometric`
- **Purpose:** 12-question adaptive quiz measuring repayment intent/financial personality (scored server-side by BERT).
- **Screens:** `psychometric_quiz_screen.dart`
- **Data model:** `quiz_model.dart` — fields: `questionId`, `questionText`, `options` (list), `selectedOptionId`, `answeredAt`.
- **Logic:** Fully in-app, first-party data — no third-party API. Submit full response set to backend scoring endpoint on completion.
- **Acceptance criteria:**
    - [ ] Questions are fetched from backend at runtime, not hardcoded (allows adaptive question sets without app updates).
    - [ ] Cannot be retaken within the same scoring cycle (backend enforces; Flutter UI should reflect a "already completed" state).

### 5.9 `location`
- **Purpose:** Capture geolocation stability signal (hashed, consent-limited) as a proxy for residential stability.
- **Screens:** `location_consent_screen.dart`
- **Logic:** Uses `geolocator` to capture GPS coordinates; coordinates are hashed **on-device** before transmission (per DPDP 2023 purpose limitation — raw lat/long should not leave the device unhashed).
- **Acceptance criteria:**
    - [ ] Raw lat/long is never sent to any repository/API call — only the geohash.
    - [ ] Requires `consent.location == granted`.
    - [ ] Gracefully handles denied OS-level location permission with a clear explanation, not a silent failure.

### 5.10 `credit_score`
- **Purpose:** Display the computed CreditDNA score (0–850), confidence band, and 3-layer report.
- **Screens:** `score_loading_screen.dart`, `score_result_screen.dart`, `report_screen.dart`
- **Data model:** `score_model.dart` — fields: `score` (int 0–850), `confidenceBand`, `stressProfile`, `characterNarrative` (plain-language text), `computedAt`.
- **API dependency:** Backend FastAPI scoring endpoint. This is triggered only after KYC verified + at least one data signal (financial_data or gst) + psychometric quiz completed.
- **Acceptance criteria:**
    - [ ] `score_loading_screen` shows real progress/status, not a fake progress bar — poll backend job status if scoring is asynchronous.
    - [ ] Score gauge (fl_chart) must visually communicate the 0–850 range with the user's position clearly marked.
    - [ ] Never fabricate or locally estimate a score if the backend call fails — show an error state instead.

### 5.11 `marketplace` (OCEN)
- **Purpose:** Broadcast the scored loan application to OCEN-registered lenders, display competing offers, let user select.
- **Screens:** `offers_list_screen.dart`, `offer_detail_screen.dart`
- **Data model:** `loan_offer_model.dart` — fields: `lenderId`, `lenderName`, `interestRate`, `tenureMonths`, `maxAmount`, `processingFee`, `offerExpiresAt`.
- **API dependency:** OCEN protocol integration (backend-mediated — Flutter calls your own backend, which handles the OCEN `LoanApplicationRequest`/`OfferResponse` exchange).
- **Acceptance criteria:**
    - [ ] Offers list must be sortable/comparable by effective rate, not just displayed in API return order.
    - [ ] Offer selection triggers `GrantRequest` flow through backend; Flutter shows real-time status (pending/accepted/disbursed).

### 5.12 `loan_status`
- **Purpose:** Track an accepted loan's status post-selection (disbursement, EMI schedule, repayment).
- **Screens:** TBD — `[OPEN DECISION: not yet detailed in pitch deck beyond "AutoPay EMI mandate activated" — confirm required screens with team before building]`

### 5.13 `data_benefit_ledger`
- **Purpose:** Transparency feature — shows the borrower exactly which data signal contributed how much to their score. Key differentiator vs. black-box bureau scores.
- **Screens:** `ledger_screen.dart`
- **Data model:** `ledger_entry_model.dart` — fields: `signalName`, `contributionWeight` (%), `lastUpdated`.
- **Acceptance criteria:**
    - [ ] Must visually sum to a clear whole (e.g., stacked bar or pie via fl_chart) — not just a raw list of numbers.

### 5.14 `dashboard`
- **Purpose:** Home screen post-onboarding — score summary, active loan status, quick links to ledger/marketplace.
- **Screens:** `home_screen.dart`, `financial_report_screen.dart`
- **Acceptance criteria:**
    - [ ] Must handle all states: no score yet, score computed no loan, active loan, loan repaid (graduated to next ladder tier).

---

## 6. Core Infrastructure Requirements (`lib/core/`)

| File | Requirement |
|---|---|
| `config/env.dart` | Holds `baseUrl` and all API keys/client IDs. Must support environment switching (sandbox vs production) via build flavor or `.env` file — never hardcode production keys in source. |
| `network/api_client.dart` | Single `Dio` instance, shared across all repositories via dependency injection (Riverpod provider), not instantiated per-feature. |
| `network/api_interceptors.dart` | Attaches JWT to every request; handles 401 → silent token refresh → retry original request; on refresh failure, force logout. |
| `network/api_endpoints.dart` | Centralized string constants for every endpoint path — no inline URL strings in repositories. |
| `network/api_exceptions.dart` | Typed exceptions per integration (e.g. `AAException`, `GSTException`, `KYCException`, `ScoringException`) so UI can show integration-specific error messaging. |
| `storage/secure_storage.dart` | Wraps `flutter_secure_storage` — used for JWT, refresh token, and any consent-artifact tokens. |
| `storage/local_storage.dart` | Non-sensitive local flags (e.g. onboarding seen). |
| `security/token_manager.dart` | JWT parsing, expiry checks, refresh orchestration. |
| `security/encryption_service.dart` | RSA-2048 payload encryption for any data leaving the device that the deck specifies as encrypted (bank data references, location hash, etc.) — `[OPEN DECISION: confirm exact payloads requiring client-side encryption vs. TLS-only with backend]`. |

---

## 7. External Integration Credentials Needed (blocker list)

The agent should treat these as blockers for the corresponding feature — do not fabricate mock keys and proceed silently; flag clearly if a task requires one of these and it is not yet available in `env.dart`.

- [ ] DigiLocker Partner sandbox client ID/secret
- [ ] Setu or Finvu AA sandbox credentials (confirm which provider)
- [ ] GST Suvidha Provider (Masters India / Cleartax) sandbox API key
- [ ] Backend base URL (Node.js/Express + FastAPI, dev/staging)
- [ ] OCEN sandbox or hackathon-provided test environment

---

## 8. Recommended Build Order

1. Core infra: `api_client.dart`, `env.dart`, `api_interceptors.dart`, `api_endpoints.dart`, `secure_storage.dart`
2. `app/app_router.dart` — full route skeleton with placeholder screens for every feature listed in Section 5
3. `auth` — signup/login, token storage
4. `kyc` — first real external API integration (DigiLocker)
5. `consent` — must exist before financial_data/gst/location/psychometric are reachable
6. `financial_data` (AA) and `gst` in parallel (different team members)
7. `psychometric` and `location`
8. `credit_score` — depends on 4–7 being complete enough to send real payloads to backend
9. `marketplace` (OCEN) and `data_benefit_ledger`
10. `dashboard` — ties everything together
11. `loan_status` — after `[OPEN DECISION]` in 5.12 is resolved

---

## 9. Non-Functional Requirements

- **Privacy:** No signal's raw data may be logged to console/crash reporting in release builds. Add lint/review step for this.
- **Consent enforcement:** Every data-collection repository method must check consent status before making an API call — not just at the UI navigation level. This is a defense-in-depth requirement, not just a UX gate.
- **Error handling:** Every repository method returns a typed result (success/failure), never lets a raw `DioException` reach the UI layer unhandled.
- **Offline behavior:** `[OPEN DECISION: not specified — default assumption is the app requires connectivity for all data-collection and scoring features; dashboard may show last-cached score offline]`.
- **Accessibility:** Standard Flutter accessibility widgets (Semantics labels) on all interactive elements — this app serves underserved users who may have lower digital literacy, so clarity matters more than brevity in copy.

---

## 10. Glossary (for agent context)

- **AA (Account Aggregator):** RBI-regulated framework for consented financial data sharing between banks (FIPs) and apps (FIUs).
- **OCEN (Open Credit Enablement Network):** Protocol standardizing loan origination between Loan Service Providers and lenders.
- **DPDP 2023:** India's Digital Personal Data Protection Act — governs consent, purpose limitation, and data minimization requirements referenced throughout this spec.
- **FIP/FIU:** Financial Information Provider / Financial Information User — AA framework roles.
- **NPA:** Non-Performing Asset — used here for the backend's early-warning default-risk model (not a Flutter concern beyond displaying alerts if surfaced).

---

## 11. How to Use This Document (agent instructions)

- Treat each numbered feature in Section 5 as a discrete task. Do not begin a feature whose listed API dependency or `[OPEN DECISION]` is unresolved — flag it instead of guessing.
- Always place new code in the path implied by Section 4's folder convention.
- Cross-reference Section 6 before writing any new networking code — infra likely already exists or has a defined location.
- When an acceptance criterion checkbox is ambiguous relative to existing code, ask rather than assume, especially around consent enforcement (Section 9) — this is a compliance-sensitive area, not a stylistic one.