/**
 * Integration tests for Webhook routes.
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
const app = require('../src/app');

describe('Webhook Routes', () => {
  beforeEach(() => jest.clearAllMocks());

  describe('POST /v1/webhooks/aa/consent', () => {
    test('400 if consentHandle missing', async () => {
      const res = await request(app).post('/v1/webhooks/aa/consent').send({});
      expect(res.status).toBe(400);
      expect(res.body.error).toMatch(/consentHandle/i);
    });

    test('acknowledges AA consent approval', async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [{ user_id: 'user-123', signal_type: 'bank' }],
      });
      const res = await request(app)
        .post('/v1/webhooks/aa/consent')
        .send({ consentHandle: 'HANDLE_ABC', status: 'ACTIVE', timestamp: new Date().toISOString() });
      expect(res.status).toBe(200);
      expect(res.body.received).toBe(true);
      expect(res.body.status).toBe('active');
    });

    test('maps REJECTED to revoked status', async () => {
      mockPool.query.mockResolvedValueOnce({ rows: [] }); // consent not found — no audit needed
      const res = await request(app)
        .post('/v1/webhooks/aa/consent')
        .send({ consentHandle: 'HANDLE_XYZ', status: 'REJECTED' });
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('revoked');
    });
  });

  describe('POST /v1/webhooks/digilocker', () => {
    test('400 if requestId missing', async () => {
      const res = await request(app).post('/v1/webhooks/digilocker').send({});
      expect(res.status).toBe(400);
    });

    test('404 for unknown requestId', async () => {
      mockPool.query.mockResolvedValueOnce({ rows: [] });
      const res = await request(app)
        .post('/v1/webhooks/digilocker')
        .send({ requestId: 'UNKNOWN_ID', status: 'approved' });
      expect(res.status).toBe(404);
    });

    test('processes approved DigiLocker callback', async () => {
      mockPool.query
        .mockResolvedValueOnce({ rows: [{ user_id: 'user-123' }] }) // find request
        .mockResolvedValueOnce({ rows: [] }) // update request status
        .mockResolvedValueOnce({ rows: [] }); // update user KYC

      const res = await request(app)
        .post('/v1/webhooks/digilocker')
        .send({
          requestId: 'DL_REQ_123',
          status: 'approved',
          kycData: { full_name: 'Test User', aadhaar_masked: 'XXXX XXXX 1234', pan: 'ABCDE1234F' },
        });
      expect(res.status).toBe(200);
      expect(res.body.received).toBe(true);
    });
  });
});
