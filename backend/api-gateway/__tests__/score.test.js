/**
 * Integration tests for Score orchestration route.
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

jest.mock('../src/config/db', () => {
  const mockPool = { query: jest.fn() };
  const mockRedis = { set: jest.fn().mockResolvedValue("OK"), get: jest.fn().mockResolvedValue(null), incr: jest.fn().mockResolvedValue(1), expire: jest.fn().mockResolvedValue(1), ttl: jest.fn().mockResolvedValue(60), connect: jest.fn(), on: jest.fn() };
  return {
    pgPool: mockPool,
    redis: mockRedis,
    connectPostgres: jest.fn(),
    connectMongo: jest.fn(),
    connectRedis: jest.fn(),
  };
});
jest.mock('../src/services/audit', () => ({ log: jest.fn() }));
jest.mock('../src/models/AuditLog', () => ({ create: jest.fn() }));
jest.mock('../src/services/vault', () => ({
  store: jest.fn().mockReturnValue('vault-key-123'),
  retrieve: jest.fn().mockReturnValue({ fipID: 'MOCK', accounts: [] }),
  remove: jest.fn(),
}));

const request = require('supertest');
const jwt = require('jsonwebtoken');
const app = require('../src/app');
const { pgPool } = require('../src/config/db');

function makeToken(userId = 'user-123', borrower_type = 'individual') {
  return jwt.sign(
    { sub: userId, phone: '9876543210', borrower_type },
    process.env.JWT_SECRET,
    { expiresIn: '15m' }
  );
}

describe('Score Routes', () => {
  beforeEach(() => jest.clearAllMocks());

  test('POST /v1/score/generate — 401 without token', async () => {
    const res = await request(app).post('/v1/score/generate');
    expect(res.status).toBe(401);
  });

  test('POST /v1/score/generate — 403 if bank consent missing', async () => {
    const token = makeToken();
    pgPool.query
      .mockResolvedValueOnce({ rows: [{ id: 'u1', phone: '9876543210', borrower_type: 'individual', kyc_verified: true }] }) // user
      .mockResolvedValueOnce({ rows: [] }); // no consents
    const res = await request(app)
      .post('/v1/score/generate')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(403);
    expect(res.body.code).toBe('CONSENT_MISSING');
  });

  test('POST /v1/score/generate — 403 if quiz consent missing', async () => {
    const token = makeToken();
    pgPool.query
      .mockResolvedValueOnce({ rows: [{ id: 'u1', phone: '9876543210', borrower_type: 'individual', kyc_verified: true }] })
      .mockResolvedValueOnce({ rows: [{ signal_type: 'bank' }] }); // bank present, quiz missing
    const res = await request(app)
      .post('/v1/score/generate')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(403);
    expect(res.body.code).toBe('CONSENT_MISSING');
  });

  test('POST /v1/score/generate — returns score for individual with bank+quiz consent', async () => {
    const token = makeToken('user-123', 'individual');
    pgPool.query
      .mockResolvedValueOnce({ rows: [{ id: 'user-123', phone: '9876543210', borrower_type: 'individual', kyc_verified: true }] })  // user
      .mockResolvedValueOnce({ rows: [{ signal_type: 'bank' }, { signal_type: 'quiz' }] })  // consents
      .mockResolvedValueOnce({ rows: [{ vault_key: 'vault-k1', fi_type: 'DEPOSIT' }] })    // aa refs
      .mockResolvedValueOnce({ rows: [{ responses: '{}', score_raw: 75 }] })                // quiz
      .mockResolvedValueOnce({ rows: [{                                                       // INSERT score
        id: 'score-id-1', score_value: 650, risk_band: 'MEDIUM', max_eligible_amount: 50000,
        signal_contributions: [], generated_at: new Date(),
      }] });

    const res = await request(app)
      .post('/v1/score/generate')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('score_id');
    expect(res.body).toHaveProperty('score_value');
    expect(res.body).toHaveProperty('risk_band');
    expect(res.body.is_mock).toBe(true);
  });

  test('POST /v1/score/generate — MSME requires GST consent', async () => {
    const token = makeToken('user-123', 'msme');
    pgPool.query
      .mockResolvedValueOnce({ rows: [{ id: 'user-123', phone: '9876543210', borrower_type: 'msme', kyc_verified: true }] })
      .mockResolvedValueOnce({ rows: [{ signal_type: 'bank' }, { signal_type: 'quiz' }] }); // no gst

    const res = await request(app)
      .post('/v1/score/generate')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(403);
    expect(res.body.error).toMatch(/GST/);
  });
});
