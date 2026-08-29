/**
 * Full end-to-end happy-path integration test.
 *
 * Simulates the complete CredNest borrower journey:
 * Register → Login → Create Consents → AA Initiate → AA Fetch → Quiz Submit
 * → Score Generate → Loan Apply → Get Offers → Select Offer → Repay → Ledger
 *
 * All DB/external calls are mocked. Tests the entire request/response pipeline.
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

// ── Shared mocks ──────────────────────────────────────────────────────────────
let offerCache = {};

const mockPool = { query: jest.fn() };
const mockRedis = {
  incr: jest.fn().mockResolvedValue(1),
  expire: jest.fn().mockResolvedValue(1),
  ttl: jest.fn().mockResolvedValue(60),
  set: jest.fn().mockImplementation((key, value) => { offerCache[key] = value; return Promise.resolve('OK'); }),
  get: jest.fn().mockImplementation((key) => Promise.resolve(offerCache[key] || null)),
  connect: jest.fn(),
  on: jest.fn(),
};

jest.mock('../src/config/db', () => ({
  pgPool: mockPool, redis: mockRedis,
  connectPostgres: jest.fn(), connectMongo: jest.fn(), connectRedis: jest.fn(),
}));
jest.mock('../src/services/audit', () => ({ log: jest.fn() }));
jest.mock('../src/models/AuditLog', () => ({ create: jest.fn() }));
jest.mock('../src/services/vault', () => ({
  store: jest.fn().mockReturnValue('e2e-vault-key'),
  retrieve: jest.fn().mockReturnValue({ fipID: 'MOCK', accounts: [{ fiType: 'DEPOSIT', data: { summary: { currentBalance: 45000 } } }] }),
  remove: jest.fn(),
}));
jest.mock('../src/services/aa-client', () => ({
  initiateConsent: jest.fn().mockResolvedValue({ consentHandle: 'E2E_CONSENT_HANDLE', redirectUrl: 'https://aa.mock/consent' }),
  fetchData: jest.fn().mockResolvedValue([{ fipID: 'E2E_FIP', accounts: [{ maskedAccNumber: 'XXX1234', fiType: 'DEPOSIT', data: {} }] }]),
}));
jest.mock('../src/services/loan-ladder.service', () => ({
  runLadderGraduation: jest.fn().mockResolvedValue({ message: 'Graduated!', next_tier: 2, next_amount: 25000, new_application_id: '123e4567-e89b-12d3-a456-426614174002' }),
  LADDER_TIERS: { 1: 10000, 2: 25000, 3: 50000 },
}));

const request = require('supertest');
const bcrypt = require('bcrypt');
const app = require('../src/app');

const TEST_PHONE = '9123456789';
const TEST_PASSWORD = 'Test@Secure99';
const TEST_USER_ID = 'e2e-user-id-001';

let accessToken;
let applicationId;
let offerId;
const loanId = '123e4567-e89b-12d3-a456-426614174001';

// ── Helpers ───────────────────────────────────────────────────────────────────
function consentRow(signalType = 'bank') {
  return { id: `consent-${signalType}`, status: 'active', expires_at: new Date(Date.now() + 999999999) };
}

describe('Full E2E Happy Path', () => {
  beforeEach(() => jest.clearAllMocks());

  // ── 1. Register ─────────────────────────────────────────────────────────────
  test('Step 1: POST /v1/auth/register — user registers successfully', async () => {
    mockPool.query
      .mockResolvedValueOnce({ rows: [] }) // no existing user
      .mockResolvedValueOnce({ rows: [{ id: TEST_USER_ID, phone: TEST_PHONE, email: null, full_name: 'E2E User', borrower_type: 'individual', created_at: new Date() }] })
      .mockResolvedValueOnce({ rows: [] }); // refresh token insert

    const res = await request(app)
      .post('/v1/auth/register')
      .send({ phone: TEST_PHONE, password: TEST_PASSWORD, full_name: 'E2E User', borrower_type: 'individual' });

    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('access_token');
    expect(res.body).toHaveProperty('refresh_token');
    expect(res.body.user.phone).toBe(TEST_PHONE);
    accessToken = res.body.access_token;
  });

  // ── 2. Create bank consent ──────────────────────────────────────────────────
  test('Step 2: POST /v1/consent — create bank consent', async () => {
    mockPool.query
      .mockResolvedValueOnce({ rows: [] }) // revoke old
      .mockResolvedValueOnce({ rows: [{ id: 'c-bank', user_id: TEST_USER_ID, signal_type: 'bank', status: 'active', granted_at: new Date(), expires_at: new Date(Date.now() + 999999) }] });

    const res = await request(app)
      .post('/v1/consent')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ signal_type: 'bank', expiry_days: 90 });

    expect(res.status).toBe(201);
    expect(res.body.consent.signal_type).toBe('bank');
  });

  // ── 3. Create quiz consent ──────────────────────────────────────────────────
  test('Step 3: POST /v1/consent — create quiz consent', async () => {
    mockPool.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{ id: 'c-quiz', user_id: TEST_USER_ID, signal_type: 'quiz', status: 'active', granted_at: new Date(), expires_at: new Date(Date.now() + 999999) }] });

    const res = await request(app)
      .post('/v1/consent')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ signal_type: 'quiz', expiry_days: 90 });

    expect(res.status).toBe(201);
    expect(res.body.consent.signal_type).toBe('quiz');
  });

  // ── 4. Initiate AA consent ──────────────────────────────────────────────────
  test('Step 4: POST /v1/aa/consent/initiate — initiate AA consent with handle', async () => {
    mockPool.query.mockResolvedValueOnce({ rows: [] }); // INSERT consent

    const res = await request(app)
      .post('/v1/aa/consent/initiate')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ fi_types: ['DEPOSIT'] });

    expect(res.status).toBe(200);
    expect(res.body.consentHandle).toBe('E2E_CONSENT_HANDLE');
    expect(res.body).toHaveProperty('redirectUrl');
  });

  // ── 5. Fetch AA data ────────────────────────────────────────────────────────
  test('Step 5: POST /v1/aa/fetch — fetch and vault AA data', async () => {
    mockPool.query
      .mockResolvedValueOnce({ rows: [consentRow('bank')] })  // consent middleware
      .mockResolvedValueOnce({ rows: [{ consent_artifact_id: 'E2E_CONSENT_HANDLE' }] }) // get handle
      .mockResolvedValueOnce({ rows: [{ id: 'ref-1' }] });   // INSERT ref

    const res = await request(app)
      .post('/v1/aa/fetch')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ fi_types: ['DEPOSIT'] });

    expect(res.status).toBe(200);
    expect(res.body.data_refs).toHaveLength(1);
  });

  // ── 6. Get quiz questions ───────────────────────────────────────────────────
  test('Step 6: GET /v1/quiz/questions — returns 12 questions', async () => {
    const res = await request(app).get('/v1/quiz/questions');
    expect(res.status).toBe(200);
    expect(res.body.total).toBe(12);
  });

  // ── 7. Submit quiz ──────────────────────────────────────────────────────────
  test('Step 7: POST /v1/quiz/submit — submit all 12 answers', async () => {
    const fullResponses = Object.fromEntries(
      Array.from({ length: 12 }, (_, i) => [`Q${String(i + 1).padStart(2, '0')}`, 3])
    );

    mockPool.query
      .mockResolvedValueOnce({ rows: [consentRow('quiz')] })   // consent middleware
      .mockResolvedValueOnce({ rows: [{ id: 'quiz-1', submitted_at: new Date(), score_raw: 75 }] }); // INSERT

    const res = await request(app)
      .post('/v1/quiz/submit')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ responses: fullResponses });

    expect(res.status).toBe(201);
    expect(res.body.score_raw).toBe(75);
  });

  // ── 8. Generate score ───────────────────────────────────────────────────────
  test('Step 8: POST /v1/score/generate — generates mock credit score', async () => {
    mockPool.query
      .mockResolvedValueOnce({ rows: [{ id: TEST_USER_ID, phone: TEST_PHONE, borrower_type: 'individual', kyc_verified: false }] }) // user
      .mockResolvedValueOnce({ rows: [{ signal_type: 'bank' }, { signal_type: 'quiz' }] })               // consents
      .mockResolvedValueOnce({ rows: [{ vault_key: 'e2e-vault-key', fi_type: 'DEPOSIT' }] })            // aa refs
      .mockResolvedValueOnce({ rows: [{ responses: '{}', score_raw: 75 }] })                             // quiz
      .mockResolvedValueOnce({ rows: [{
        id: 'score-e2e-1', score_value: 680, risk_band: 'MEDIUM', max_eligible_amount: 50000,
        signal_contributions: [], generated_at: new Date(),
      }] });  // INSERT score

    const res = await request(app)
      .post('/v1/score/generate')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(res.status).toBe(200);
    expect(res.body.score_value).toBeGreaterThan(300);
    expect(['LOW', 'MEDIUM', 'HIGH']).toContain(res.body.risk_band);
    expect(res.body.is_mock).toBe(true);
  });

  // ── 9. Apply for loan ───────────────────────────────────────────────────────
  test('Step 9: POST /v1/loans/apply — apply for loan and get offers', async () => {
    mockPool.query
      .mockResolvedValueOnce({ rows: [{ id: 'score-e2e-1', score_value: 680, risk_band: 'MEDIUM', max_eligible_amount: 50000 }] }) // score
      .mockResolvedValueOnce({ rows: [{ id: loanId, status: 'pending', amount_requested: 25000 }] })  // INSERT loan
      .mockResolvedValueOnce({ rows: [] }); // UPDATE status

    const res = await request(app)
      .post('/v1/loans/apply')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ amount: 25000, purpose: 'E2E test capital' });

    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('application_id');
    expect(res.body.offers_count).toBeGreaterThanOrEqual(2);
    applicationId = res.body.application_id;
  });

  // ── 10. Get offers ──────────────────────────────────────────────────────────
  test('Step 10: GET /v1/loans/offers/:id — returns ranked offers', async () => {
    mockPool.query.mockResolvedValueOnce({ rows: [{ id: applicationId, user_id: TEST_USER_ID }] });

    const res = await request(app)
      .get(`/v1/loans/offers/${applicationId}`)
      .set('Authorization', `Bearer ${accessToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.offers)).toBe(true);
    expect(res.body.offers.length).toBeGreaterThan(0);
    // Pick an offer for next step
    offerId = res.body.offers[0].offerId;
  });

  // ── 11. Select offer ────────────────────────────────────────────────────────
  test('Step 11: POST /v1/loans/select — select offer and get disbursement', async () => {
    expect(offerId).toBeDefined(); // guard: must come from step 10

    mockPool.query.mockResolvedValueOnce({ rows: [] }); // UPDATE loan

    const res = await request(app)
      .post('/v1/loans/select')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ application_id: applicationId, offer_id: offerId });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('disbursement');
    expect(res.body.disbursement.status).toBe('DISBURSED');
    expect(res.body.disbursement).toHaveProperty('grantId');
    expect(res.body.disbursement).toHaveProperty('loanAmount');
  });

  // ── 12. Record repayment (full) → ladder graduation ─────────────────────────
  test('Step 12: POST /v1/loans/:id/repay — full repayment triggers ladder graduation', async () => {
    mockPool.query
      .mockResolvedValueOnce({ rows: [{ id: loanId, user_id: TEST_USER_ID, status: 'disbursed', amount_approved: 25000, amount_requested: 25000, ladder_tier: 1 }] }) // loan
      .mockResolvedValueOnce({ rows: [{ id: 'repay-1', paid_at: new Date() }] })  // INSERT repayment
      .mockResolvedValueOnce({ rows: [{ total: '25000.00' }] })                    // SUM repayments
      .mockResolvedValueOnce({ rows: [] });                                         // UPDATE loan to repaid

    const res = await request(app)
      .post(`/v1/loans/${loanId}/repay`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ amount: 25000 });

    expect(res.status).toBe(200);
    expect(res.body.loan_status).toBe('repaid');
    expect(res.body).toHaveProperty('ladder_upgrade');
    expect(res.body.ladder_upgrade.message).toMatch(/graduated/i);
  });

  // ── 13. Check data benefit ledger ───────────────────────────────────────────
  test('Step 13: GET /v1/ledger/:userId — returns signal contributions', async () => {
    mockPool.query.mockResolvedValueOnce({
      rows: [{
        id: 'score-e2e-1',
        score_value: 680,
        risk_band: 'MEDIUM',
        signal_contributions: [
          { signal: 'bank_statements', weight: 0.35, contribution: 238 },
          { signal: 'psychometric_quiz', weight: 0.25, contribution: 170 },
          { signal: 'gst_data', weight: 0.20, contribution: 136 },
          { signal: 'upi_behavior', weight: 0.20, contribution: 136 },
        ],
        generated_at: new Date(),
      }],
    });

    const res = await request(app)
      .get(`/v1/ledger/${TEST_USER_ID}`)
      .set('Authorization', `Bearer ${accessToken}`);

    expect(res.status).toBe(200);
    expect(res.body.score_value).toBe(680);
    expect(res.body.data_benefit_ledger).toHaveLength(4);
    const bankEntry = res.body.data_benefit_ledger.find(e => e.signal === 'bank_statements');
    expect(bankEntry).toBeDefined();
    expect(bankEntry.percentage).toBe('35.0%');
  });
});
