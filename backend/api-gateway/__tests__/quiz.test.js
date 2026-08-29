/**
 * Integration tests for Quiz routes.
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

const request = require('supertest');
const jwt = require('jsonwebtoken');
const app = require('../src/app');
const { pgPool } = require('../src/config/db');

function makeToken(userId = 'user-123') {
  return jwt.sign(
    { sub: userId, phone: '9876543210', borrower_type: 'individual' },
    process.env.JWT_SECRET,
    { expiresIn: '15m' }
  );
}

describe('Quiz Routes', () => {
  beforeEach(() => jest.clearAllMocks());

  test('GET /v1/quiz/questions returns 12 questions without auth', async () => {
    const res = await request(app).get('/v1/quiz/questions');
    expect(res.status).toBe(200);
    expect(res.body.questions).toHaveLength(12);
    expect(res.body.total).toBe(12);
  });

  test('GET /v1/quiz/questions — each question has id, text, options', async () => {
    const res = await request(app).get('/v1/quiz/questions');
    for (const q of res.body.questions) {
      expect(q).toHaveProperty('id');
      expect(q).toHaveProperty('text');
      expect(q).toHaveProperty('options');
      expect(q.options).toHaveLength(4);
    }
  });

  test('POST /v1/quiz/submit requires auth', async () => {
    const res = await request(app).post('/v1/quiz/submit').send({});
    expect(res.status).toBe(401);
  });

  test('POST /v1/quiz/submit returns 403 without quiz consent', async () => {
    const token = makeToken();
    // consent.middleware queries for active consent — return empty
    pgPool.query.mockResolvedValueOnce({ rows: [] });
    const res = await request(app)
      .post('/v1/quiz/submit')
      .set('Authorization', `Bearer ${token}`)
      .send({ responses: {} });
    expect(res.status).toBe(403);
    expect(res.body.code).toBe('CONSENT_MISSING_OR_EXPIRED');
  });

  test('POST /v1/quiz/submit returns 400 with incomplete responses', async () => {
    const token = makeToken();
    // consent passes
    pgPool.query.mockResolvedValueOnce({ rows: [{ id: 'c-1', status: 'active', expires_at: new Date(Date.now() + 9999999) }] });
    const res = await request(app)
      .post('/v1/quiz/submit')
      .set('Authorization', `Bearer ${token}`)
      .send({ responses: { Q01: 3 } }); // only 1 of 12
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/Missing answers/i);
  });

  test('POST /v1/quiz/submit succeeds with all 12 answers', async () => {
    const token = makeToken();
    const fullResponses = {};
    for (let i = 1; i <= 12; i++) {
      fullResponses[`Q${String(i).padStart(2, '0')}`] = 3;
    }
    // consent passes, then INSERT query
    pgPool.query
      .mockResolvedValueOnce({ rows: [{ id: 'c-1', status: 'active', expires_at: new Date(Date.now() + 9999999) }] })
      .mockResolvedValueOnce({ rows: [{ id: 'quiz-id-1', submitted_at: new Date(), score_raw: 75 }] });

    const res = await request(app)
      .post('/v1/quiz/submit')
      .set('Authorization', `Bearer ${token}`)
      .send({ responses: fullResponses });
    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('quiz_id');
    expect(res.body.score_raw).toBe(75);
  });
});
