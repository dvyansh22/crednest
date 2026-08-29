/**
 * Integration tests for Loan/OCEN routes.
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

jest.mock('../src/config/db', () => {
  const mockPool = { query: jest.fn() };
  const mockRedis = {
    set: jest.fn().mockResolvedValue('OK'),
    get: jest.fn().mockResolvedValue(null),
    incr: jest.fn().mockResolvedValue(1),
    expire: jest.fn().mockResolvedValue(1),
    ttl: jest.fn().mockResolvedValue(60),
    connect: jest.fn(),
    on: jest.fn(),
  };
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
jest.mock('../src/services/loan-ladder.service', () => ({
  runLadderGraduation: jest.fn().mockResolvedValue({ message: 'Graduated', next_tier: 2 }),
  LADDER_TIERS: { 1: 10000, 2: 25000, 3: 50000, 4: 100000, 5: 200000 },
}));

const request = require('supertest');
const jwt = require('jsonwebtoken');
const app = require('../src/app');
const { pgPool, redis } = require('../src/config/db');

function makeToken(userId = 'user-123') {
  return jwt.sign(
    { sub: userId, phone: '9876543210', borrower_type: 'individual' },
    process.env.JWT_SECRET,
    { expiresIn: '15m' }
  );
}

describe('Loan Routes', () => {
  beforeEach(() => jest.clearAllMocks());

  test('POST /v1/loans/apply — 401 without auth', async () => {
    const res = await request(app).post('/v1/loans/apply').send({});
    expect(res.status).toBe(401);
  });

  test('POST /v1/loans/apply — 400 if amount missing', async () => {
    const token = makeToken();
    const res = await request(app)
      .post('/v1/loans/apply')
      .set('Authorization', `Bearer ${token}`)
      .send({ purpose: 'Test' });
    expect(res.status).toBe(400);
    expect(res.body.details).toEqual(expect.arrayContaining([
      expect.objectContaining({ field: expect.stringMatching(/amount/i) })
    ]));
  });

  test('POST /v1/loans/apply — 400 if no score found', async () => {
    const token = makeToken();
    pgPool.query.mockResolvedValueOnce({ rows: [] }); // no score
    const res = await request(app)
      .post('/v1/loans/apply')
      .set('Authorization', `Bearer ${token}`)
      .send({ amount: 25000 });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/score/i);
  });

  test('POST /v1/loans/apply — 400 if amount exceeds max eligible', async () => {
    const token = makeToken();
    pgPool.query.mockResolvedValueOnce({
      rows: [{ id: 'score-1', score_value: 600, risk_band: 'MEDIUM', max_eligible_amount: 10000 }],
    });
    const res = await request(app)
      .post('/v1/loans/apply')
      .set('Authorization', `Bearer ${token}`)
      .send({ amount: 50000 });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/exceeds/i);
  });

  test('POST /v1/loans/apply — 201 with valid score and amount', async () => {
    const token = makeToken();
    pgPool.query
      .mockResolvedValueOnce({ rows: [{ id: 'score-1', score_value: 700, risk_band: 'LOW', max_eligible_amount: 100000 }] })  // score
      .mockResolvedValueOnce({ rows: [{ id: 'loan-app-1', status: 'pending', amount_requested: 25000 }] })  // INSERT loan
      .mockResolvedValueOnce({ rows: [] });  // UPDATE status

    redis.set.mockResolvedValue('OK');

    const res = await request(app)
      .post('/v1/loans/apply')
      .set('Authorization', `Bearer ${token}`)
      .send({ amount: 25000, purpose: 'Business capital' });

    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('application_id');
    expect(res.body.offers_count).toBeGreaterThanOrEqual(2);
  });

  test('GET /v1/loans/offers/:id — 404 if offers expired', async () => {
    const token = makeToken();
    pgPool.query.mockResolvedValueOnce({ rows: [{ id: 'loan-app-1', user_id: 'user-123' }] });
    redis.get.mockResolvedValueOnce(null);
    const res = await request(app)
      .get('/v1/loans/offers/loan-app-1')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(404);
  });

  test('GET /v1/loans/offers/:id — returns sorted offers from Redis', async () => {
    const token = makeToken();
    pgPool.query.mockResolvedValueOnce({ rows: [{ id: 'loan-app-1', user_id: 'user-123' }] });
    const mockOffers = [
      { offerId: 'o1', totalRepayable: 30000, lenderName: 'A' },
      { offerId: 'o2', totalRepayable: 28000, lenderName: 'B' },
    ];
    redis.get.mockResolvedValueOnce(JSON.stringify(mockOffers));

    const res = await request(app)
      .get('/v1/loans/offers/loan-app-1')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.offers[0].totalRepayable).toBeLessThanOrEqual(res.body.offers[1]?.totalRepayable || Infinity);
  });
});
