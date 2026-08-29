/**
 * Integration tests for Ledger route.
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

const mockPool = { query: jest.fn() };
const mockRedis = { incr: jest.fn().mockResolvedValue(1), expire: jest.fn(), ttl: jest.fn().mockResolvedValue(60), set: jest.fn(), get: jest.fn(), connect: jest.fn(), on: jest.fn() };

jest.mock('../src/config/db', () => ({
  pgPool: mockPool, redis: mockRedis,
  connectPostgres: jest.fn(), connectMongo: jest.fn(), connectRedis: jest.fn(),
}));
jest.mock('../src/services/audit', () => ({ log: jest.fn() }));
jest.mock('../src/models/AuditLog', () => ({ create: jest.fn() }));

const request = require('supertest');
const jwt = require('jsonwebtoken');
const app = require('../src/app');

function makeToken(userId = 'user-123') {
  return jwt.sign({ sub: userId, phone: '9876543210', borrower_type: 'individual' }, process.env.JWT_SECRET, { expiresIn: '15m' });
}

const MOCK_SIGNAL_CONTRIBUTIONS = [
  { signal: 'bank_statements', weight: 0.35, contribution: 238 },
  { signal: 'psychometric_quiz', weight: 0.25, contribution: 170 },
  { signal: 'gst_data', weight: 0.20, contribution: 136 },
  { signal: 'upi_behavior', weight: 0.20, contribution: 136 },
];

describe('Ledger Route', () => {
  beforeEach(() => jest.clearAllMocks());

  test('401 without auth', async () => {
    const res = await request(app).get('/v1/ledger/user-123');
    expect(res.status).toBe(401);
  });

  test('403 for accessing another user ledger', async () => {
    const token = makeToken('user-abc');
    const res = await request(app)
      .get('/v1/ledger/user-xyz')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(403);
  });

  test('404 if no score exists', async () => {
    const token = makeToken();
    mockPool.query.mockResolvedValueOnce({ rows: [] });
    const res = await request(app)
      .get('/v1/ledger/user-123')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(404);
  });

  test('returns formatted data benefit ledger', async () => {
    const token = makeToken();
    mockPool.query.mockResolvedValueOnce({
      rows: [{
        id: 'score-1',
        score_value: 680,
        risk_band: 'MEDIUM',
        signal_contributions: MOCK_SIGNAL_CONTRIBUTIONS,
        generated_at: new Date(),
      }],
    });

    const res = await request(app)
      .get('/v1/ledger/user-123')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('score_id');
    expect(res.body).toHaveProperty('score_value', 680);
    expect(res.body).toHaveProperty('risk_band', 'MEDIUM');
    expect(res.body).toHaveProperty('data_benefit_ledger');
    expect(res.body.data_benefit_ledger).toHaveLength(4);
    // Each ledger entry should have a percentage field
    for (const entry of res.body.data_benefit_ledger) {
      expect(entry).toHaveProperty('signal');
      expect(entry).toHaveProperty('weight');
      expect(entry).toHaveProperty('contribution');
      expect(entry).toHaveProperty('percentage');
      expect(entry.percentage).toMatch(/%$/);
    }
  });

  test('signal weights in ledger sum to 100%', async () => {
    const token = makeToken();
    mockPool.query.mockResolvedValueOnce({
      rows: [{
        id: 'score-2',
        score_value: 720,
        risk_band: 'LOW',
        signal_contributions: MOCK_SIGNAL_CONTRIBUTIONS,
        generated_at: new Date(),
      }],
    });

    const res = await request(app)
      .get('/v1/ledger/user-123')
      .set('Authorization', `Bearer ${token}`);

    const totalWeight = res.body.data_benefit_ledger.reduce((sum, e) => sum + e.weight, 0);
    expect(totalWeight).toBeCloseTo(1.0, 5);
  });
});
