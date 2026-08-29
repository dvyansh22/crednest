-- CredNest API Gateway — PostgreSQL Schema
-- Run: psql $DATABASE_URL -f src/config/migrations/001_init.sql

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── Users ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone           VARCHAR(15) UNIQUE NOT NULL,
  email           VARCHAR(255) UNIQUE,
  password_hash   TEXT,
  full_name       VARCHAR(255),
  borrower_type   VARCHAR(20) DEFAULT 'individual' CHECK (borrower_type IN ('individual', 'msme')),
  -- KYC fields from DigiLocker
  aadhaar_masked  VARCHAR(20),
  pan             VARCHAR(10),
  kyc_verified    BOOLEAN DEFAULT FALSE,
  kyc_verified_at TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ─── Refresh Tokens ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL UNIQUE,
  expires_at  TIMESTAMPTZ NOT NULL,
  revoked     BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id);

-- ─── Consents ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS consents (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  signal_type           VARCHAR(30) NOT NULL CHECK (signal_type IN ('bank', 'gst', 'location', 'quiz', 'digilocker')),
  status                VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'revoked', 'expired', 'pending')),
  granted_at            TIMESTAMPTZ DEFAULT NOW(),
  expires_at            TIMESTAMPTZ NOT NULL,
  revoked_at            TIMESTAMPTZ,
  consent_artifact_id   TEXT,           -- Setu AA consent handle
  setu_request_id       TEXT,           -- For DigiLocker/AA request tracking
  metadata              JSONB DEFAULT '{}',
  created_at            TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_consents_user_signal ON consents(user_id, signal_type);
CREATE INDEX IF NOT EXISTS idx_consents_status ON consents(status);

-- ─── Quiz Responses ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS quiz_responses (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  responses   JSONB NOT NULL,   -- { question_id: answer_value }
  score_raw   NUMERIC(5,2),     -- pre-computed psychometric score
  submitted_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_quiz_responses_user ON quiz_responses(user_id);

-- ─── Scores ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS scores (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  score_value           NUMERIC(5,2) NOT NULL,
  risk_band             VARCHAR(20),       -- LOW / MEDIUM / HIGH
  max_eligible_amount   NUMERIC(15,2),
  signal_contributions  JSONB,             -- [{signal, weight, contribution}]
  raw_response          JSONB,             -- full ml-service response
  generated_at          TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_scores_user ON scores(user_id);

-- ─── Loan Applications ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS loan_applications (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  score_id          UUID REFERENCES scores(id),
  status            VARCHAR(30) DEFAULT 'pending' CHECK (status IN ('pending', 'offers_received', 'selected', 'disbursed', 'active', 'repaid', 'npa')),
  amount_requested  NUMERIC(15,2),
  ladder_tier       INTEGER DEFAULT 1,
  purpose           TEXT,
  selected_offer_id TEXT,
  lender_id         TEXT,
  interest_rate     NUMERIC(5,2),
  tenure_months     INTEGER,
  amount_approved   NUMERIC(15,2),
  disbursed_at      TIMESTAMPTZ,
  due_date          TIMESTAMPTZ,
  ocen_request      JSONB,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_loans_user ON loan_applications(user_id);
CREATE INDEX IF NOT EXISTS idx_loans_status ON loan_applications(status);

-- ─── Repayments ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS repayments (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  loan_id     UUID NOT NULL REFERENCES loan_applications(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount      NUMERIC(15,2) NOT NULL,
  status      VARCHAR(20) DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed')),
  paid_at     TIMESTAMPTZ DEFAULT NOW(),
  metadata    JSONB DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_repayments_loan ON repayments(loan_id);

-- ─── AA Data References ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS aa_data_refs (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  consent_id    UUID REFERENCES consents(id),
  fi_type       VARCHAR(30) NOT NULL,   -- DEPOSIT, RECURRING_DEPOSIT, TERM_DEPOSIT, MUTUAL_FUNDS, etc.
  vault_key     TEXT NOT NULL,          -- pointer to encrypted file in vault
  fetched_at    TIMESTAMPTZ DEFAULT NOW(),
  data_range_from TIMESTAMPTZ,
  data_range_to   TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_aa_data_refs_user ON aa_data_refs(user_id);

-- ─── DigiLocker Requests ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS digilocker_requests (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID REFERENCES users(id) ON DELETE CASCADE,
  request_id    TEXT UNIQUE NOT NULL,   -- Setu request ID
  status        VARCHAR(20) DEFAULT 'pending',
  redirect_url  TEXT,
  kyc_data      JSONB,                  -- masked: {name, aadhaar_masked, pan}
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ─── Trigger: updated_at ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN
  CREATE TRIGGER set_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER set_loans_updated_at BEFORE UPDATE ON loan_applications FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER set_digilocker_updated_at BEFORE UPDATE ON digilocker_requests FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
