/**
 * Integration tests for Auth routes.
 * Uses supertest — requires a real Postgres/Redis instance.
 * Run after: docker-compose up && npm run migrate
 */

const request = require('supertest');

// Load test env before anything
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

// Mock DB connections so tests don't need real DBs running
jest.mock('../src/config/db', () => {
  const mockPool = {
    query: jest.fn(),
    connect: jest.fn().mockResolvedValue({
      query: jest.fn(),
      release: jest.fn(),
    }),
  };
  const mockRedis = {
    set: jest.fn().mockResolvedValue('OK'),
    get: jest.fn().mockResolvedValue(null),
    incr: jest.fn().mockResolvedValue(1),
    expire: jest.fn().mockResolvedValue(1),
    ttl: jest.fn().mockResolvedValue(60),
    connect: jest.fn().mockResolvedValue(undefined),
    on: jest.fn(),
  };
  return {
    pgPool: mockPool,
    redis: mockRedis,
    connectPostgres: jest.fn().mockResolvedValue(undefined),
    connectMongo: jest.fn().mockResolvedValue(undefined),
    connectRedis: jest.fn().mockResolvedValue(undefined),
  };
});

jest.mock('../src/services/audit', () => ({
  log: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../src/models/AuditLog', () => ({
  create: jest.fn().mockResolvedValue({}),
}));

const app = require('../src/app');
const { pgPool, redis } = require('../src/config/db');

describe('POST /v1/auth/register', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('returns 400 if phone missing', async () => {
    const res = await request(app)
      .post('/v1/auth/register')
      .send({ password: 'Test@1234' });
    expect(res.status).toBe(400);
    expect(res.body.details).toEqual(expect.arrayContaining([
      expect.objectContaining({ field: expect.stringMatching(/phone/i) })
    ]));
  });

  test('returns 400 if password missing', async () => {
    const res = await request(app)
      .post('/v1/auth/register')
      .send({ phone: '9876543210' });
    expect(res.status).toBe(400);
    expect(res.body.details).toEqual(expect.arrayContaining([
      expect.objectContaining({ field: expect.stringMatching(/password/i) })
    ]));
  });

  test('returns 409 if user already exists', async () => {
    pgPool.query
      .mockResolvedValueOnce({ rows: [{ id: 'existing-user' }] }); // SELECT check
    const res = await request(app)
      .post('/v1/auth/register')
      .send({ phone: '9876543210', password: 'Test@1234' });
    expect(res.status).toBe(409);
  });

  test('registers successfully and returns tokens', async () => {
    pgPool.query
      .mockResolvedValueOnce({ rows: [] }) // SELECT (no existing user)
      .mockResolvedValueOnce({ rows: [{ id: 'new-user-id', phone: '9876543210', email: null, full_name: null, borrower_type: 'individual', created_at: new Date() }] }) // INSERT user
      .mockResolvedValueOnce({ rows: [] }); // INSERT refresh_token
    redis.set.mockResolvedValue('OK');

    const res = await request(app)
      .post('/v1/auth/register')
      .send({ phone: '9876543210', password: 'Test@1234', borrower_type: 'individual' });

    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('access_token');
    expect(res.body).toHaveProperty('refresh_token');
    expect(res.body.user.phone).toBe('9876543210');
  });
});

describe('POST /v1/auth/login', () => {
  test('returns 400 if phone missing', async () => {
    const res = await request(app).post('/v1/auth/login').send({ password: 'abc' });
    expect(res.status).toBe(400);
  });

  test('returns 401 if user not found', async () => {
    pgPool.query.mockResolvedValueOnce({ rows: [] });
    const res = await request(app).post('/v1/auth/login').send({ phone: '9999999999', password: 'pass' });
    expect(res.status).toBe(401);
  });
});

describe('GET /health', () => {
  test('returns 200 with status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});

describe('Protected routes require auth', () => {
  test('GET /v1/consent/:userId returns 401 without token', async () => {
    const res = await request(app).get('/v1/consent/some-user-id');
    expect(res.status).toBe(401);
  });

  test('POST /v1/score/generate returns 401 without token', async () => {
    const res = await request(app).post('/v1/score/generate');
    expect(res.status).toBe(401);
  });

  test('POST /v1/loans/apply returns 401 without token', async () => {
    const res = await request(app).post('/v1/loans/apply');
    expect(res.status).toBe(401);
  });
});
