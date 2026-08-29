/**
 * Integration tests for GST routes.
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

const mockPool = { query: jest.fn() };
const mockRedis = {
  incr: jest.fn().mockResolvedValue(1), expire: jest.fn(), ttl: jest.fn().mockResolvedValue(60),
  set: jest.fn(), get: jest.fn(), connect: jest.fn(), on: jest.fn(),
};

jest.mock('../src/config/db', () => ({
  pgPool: mockPool, redis: mockRedis,
  connectPostgres: jest.fn(), connectMongo: jest.fn(), connectRedis: jest.fn(),
}));
jest.mock('../src/services/audit', () => ({ log: jest.fn() }));
jest.mock('../src/models/AuditLog', () => ({ create: jest.fn() }));
jest.mock('../src/services/vault', () => ({ store: jest.fn().mockReturnValue('gst-vault-key-1'), retrieve: jest.fn(), remove: jest.fn() }));
jest.mock('../src/services/gsp-client', () => ({
  verifyGstin: jest.fn().mockResolvedValue({ gstin: '29ABCDE1234F1Z5', status: 'Active', legalName: 'Test MSME Ltd' }),
  fetchGstReturns: jest.fn().mockResolvedValue({
    GSTR3B: { totalTaxLiability: 125000, avgMonthlyTurnover: 850000, filingCompliance: 0.9 },
    GSTR1: { totalInvoiceValue: 10200000 },
  }),
}));

const request = require('supertest');
const jwt = require('jsonwebtoken');
const app = require('../src/app');

function makeToken(userId = 'u1', borrower_type = 'msme') {
  return jwt.sign({ sub: userId, phone: '9876543210', borrower_type }, process.env.JWT_SECRET, { expiresIn: '15m' });
}

describe('GST Routes', () => {
  beforeEach(() => jest.clearAllMocks());

  describe('POST /v1/gst/verify', () => {
    test('401 without auth', async () => {
      const res = await request(app).post('/v1/gst/verify');
      expect(res.status).toBe(401);
    });

    test('400 for invalid GSTIN format', async () => {
      const res = await request(app)
        .post('/v1/gst/verify')
        .set('Authorization', `Bearer ${makeToken()}`)
        .send({ gstin: 'INVALID' });
      expect(res.status).toBe(400);
    });

    test('returns GSTIN details for valid GSTIN', async () => {
      const res = await request(app)
        .post('/v1/gst/verify')
        .set('Authorization', `Bearer ${makeToken()}`)
        .send({ gstin: '29ABCDE1234F1Z5' });
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('Active');
      expect(res.body.gstin).toBe('29ABCDE1234F1Z5');
    });
  });

  describe('POST /v1/gst/fetch', () => {
    test('401 without auth', async () => {
      const res = await request(app).post('/v1/gst/fetch');
      expect(res.status).toBe(401);
    });

    test('403 without gst consent', async () => {
      const token = makeToken();
      mockPool.query.mockResolvedValueOnce({ rows: [] }); // no consent
      const res = await request(app)
        .post('/v1/gst/fetch')
        .set('Authorization', `Bearer ${token}`)
        .send({ gstin: '29ABCDE1234F1Z5' });
      expect(res.status).toBe(403);
      expect(res.body.code).toBe('CONSENT_MISSING_OR_EXPIRED');
    });

    test('403 for non-MSME borrower even with consent', async () => {
      // Individual user token
      const token = makeToken('u1', 'individual');
      mockPool.query
        .mockResolvedValueOnce({ rows: [{ id: 'c-1', status: 'active', expires_at: new Date(Date.now() + 9999999) }] }) // consent passes
        .mockResolvedValueOnce({ rows: [{ borrower_type: 'individual' }] }); // user lookup

      const res = await request(app)
        .post('/v1/gst/fetch')
        .set('Authorization', `Bearer ${token}`)
        .send({ gstin: '29ABCDE1234F1Z5' });
      expect(res.status).toBe(403);
      expect(res.body.error).toMatch(/MSME/);
    });

    test('successfully fetches GST data for MSME borrower', async () => {
      const token = makeToken('u1', 'msme');
      mockPool.query
        .mockResolvedValueOnce({ rows: [{ id: 'c-1', status: 'active', expires_at: new Date(Date.now() + 9999999) }] }) // consent
        .mockResolvedValueOnce({ rows: [{ borrower_type: 'msme' }] }) // user
        .mockResolvedValueOnce({ rows: [] }); // INSERT aa_data_ref

      const res = await request(app)
        .post('/v1/gst/fetch')
        .set('Authorization', `Bearer ${token}`)
        .send({ gstin: '29ABCDE1234F1Z5', from_period: '202301', to_period: '202312' });

      expect(res.status).toBe(200);
      expect(res.body.message).toMatch(/fetched and stored/i);
      expect(res.body).toHaveProperty('summary');
    });
  });
});
