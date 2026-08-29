/**
 * Integration tests for Consent routes.
 */

require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

jest.mock('../src/config/db', () => {
  const mockPool = { query: jest.fn() };
  const mockRedis = { set: jest.fn().mockResolvedValue('OK'), get: jest.fn(), incr: jest.fn().mockResolvedValue(1), expire: jest.fn().mockResolvedValue(1), ttl: jest.fn().mockResolvedValue(60), connect: jest.fn(), on: jest.fn() };
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

describe('Consent Routes', () => {
  beforeEach(() => jest.clearAllMocks());

  test('POST /v1/consent returns 400 for invalid signal_type', async () => {
    const token = makeToken();
    const res = await request(app)
      .post('/v1/consent')
      .set('Authorization', `Bearer ${token}`)
      .send({ signal_type: 'invalid', expiry_days: 30 });
    expect(res.status).toBe(400);
  });

  test('POST /v1/consent creates consent for valid signal_type', async () => {
    const token = makeToken();
    pgPool.query
      .mockResolvedValueOnce({ rows: [] }) // UPDATE old consents (revoke prior)
      .mockResolvedValueOnce({ rows: [{ id: 'consent-id-1', user_id: 'user-123', signal_type: 'bank', status: 'active', granted_at: new Date(), expires_at: new Date() }] }); // INSERT

    const res = await request(app)
      .post('/v1/consent')
      .set('Authorization', `Bearer ${token}`)
      .send({ signal_type: 'bank', expiry_days: 90 });
    expect(res.status).toBe(201);
    expect(res.body.consent.signal_type).toBe('bank');
  });

  test('GET /v1/consent/:userId returns 403 for different user', async () => {
    const token = makeToken('user-abc');
    const res = await request(app)
      .get('/v1/consent/other-user-id')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(403);
  });

  test('DELETE /v1/consent/:consentId returns 404 for non-existent consent', async () => {
    const token = makeToken();
    pgPool.query.mockResolvedValueOnce({ rows: [] });
    const res = await request(app)
      .delete('/v1/consent/non-existent-id')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(404);
  });
});
