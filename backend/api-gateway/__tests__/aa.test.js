/**
 * Integration tests for AA routes.
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

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

jest.mock('../src/config/db', () => ({
  pgPool: mockPool,
  redis: mockRedis,
  connectPostgres: jest.fn(),
  connectMongo: jest.fn(),
  connectRedis: jest.fn(),
}));
jest.mock('../src/services/audit', () => ({ log: jest.fn() }));
jest.mock('../src/models/AuditLog', () => ({ create: jest.fn() }));
jest.mock('../src/services/vault', () => ({
  store: jest.fn().mockReturnValue('vault-key-test-1'),
  retrieve: jest.fn().mockReturnValue({ fipID: 'MOCK_FIP', accounts: [] }),
  remove: jest.fn(),
}));
// AA client always returns mock data in tests
jest.mock('../src/services/aa-client', () => ({
  initiateConsent: jest.fn().mockResolvedValue({
    consentHandle: 'MOCK_HANDLE_123',
    redirectUrl: 'https://aa-sandbox.setu.co/mock',
  }),
  fetchData: jest.fn().mockResolvedValue([
    { fipID: 'MOCK_FIP', accounts: [{ maskedAccNumber: 'XXXX1234', fiType: 'DEPOSIT', data: {} }] },
  ]),
}));

const request = require('supertest');
const jwt = require('jsonwebtoken');
const app = require('../src/app');

function makeToken(userId = 'user-123') {
  return jwt.sign(
    { sub: userId, phone: '9876543210', borrower_type: 'individual' },
    process.env.JWT_SECRET,
    { expiresIn: '15m' }
  );
}

describe('AA Routes', () => {
  beforeEach(() => jest.clearAllMocks());

  describe('POST /v1/aa/consent/initiate', () => {
    test('401 without auth', async () => {
      const res = await request(app).post('/v1/aa/consent/initiate');
      expect(res.status).toBe(401);
    });

    test('returns consentHandle and redirectUrl', async () => {
      const token = makeToken();
      // INSERT consent
      mockPool.query.mockResolvedValueOnce({ rows: [] });

      const res = await request(app)
        .post('/v1/aa/consent/initiate')
        .set('Authorization', `Bearer ${token}`)
        .send({ fi_types: ['DEPOSIT'] });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('consentHandle');
      expect(res.body).toHaveProperty('redirectUrl');
    });
  });

  describe('POST /v1/aa/fetch', () => {
    test('401 without auth', async () => {
      const res = await request(app).post('/v1/aa/fetch');
      expect(res.status).toBe(401);
    });

    test('403 without bank consent', async () => {
      const token = makeToken();
      // consent middleware — no active consent
      mockPool.query.mockResolvedValueOnce({ rows: [] });

      const res = await request(app)
        .post('/v1/aa/fetch')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(403);
      expect(res.body.code).toBe('CONSENT_MISSING_OR_EXPIRED');
    });

    test('fetches and stores data with active bank consent', async () => {
      const token = makeToken();
      // consent middleware passes
      mockPool.query
        .mockResolvedValueOnce({ rows: [{ id: 'c-1', status: 'active', expires_at: new Date(Date.now() + 9999999) }] })
        // get consent handle
        .mockResolvedValueOnce({ rows: [{ consent_artifact_id: 'MOCK_HANDLE_123' }] })
        // INSERT aa_data_ref
        .mockResolvedValueOnce({ rows: [{ id: 'ref-1' }] });

      const res = await request(app)
        .post('/v1/aa/fetch')
        .set('Authorization', `Bearer ${token}`)
        .send({ fi_types: ['DEPOSIT'] });

      expect(res.status).toBe(200);
      expect(res.body.message).toMatch(/fetched and stored/i);
      expect(res.body.data_refs).toHaveLength(1);
    });
  });
});
