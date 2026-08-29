/**
 * Unit tests for Zod validation middleware.
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

const { validate, schemas } = require('../src/middleware/validate.middleware');

// Helper to create mock req/res/next
function mockMW(body = {}, params = {}, query = {}) {
  const req = { body, params, query };
  const res = {
    status: jest.fn().mockReturnThis(),
    json: jest.fn().mockReturnThis(),
  };
  const next = jest.fn();
  return { req, res, next };
}

describe('validate middleware', () => {
  describe('registerSchema', () => {
    test('passes valid registration data', () => {
      const { req, res, next } = mockMW({ phone: '9876543210', password: 'Test@1234' });
      validate({ body: schemas.registerSchema })(req, res, next);
      expect(next).toHaveBeenCalled();
      expect(res.status).not.toHaveBeenCalled();
    });

    test('fails if phone missing', () => {
      const { req, res, next } = mockMW({ password: 'Test@1234' });
      validate({ body: schemas.registerSchema })(req, res, next);
      expect(res.status).toHaveBeenCalledWith(400);
      expect(next).not.toHaveBeenCalled();
    });

    test('fails if password too short', () => {
      const { req, res, next } = mockMW({ phone: '9876543210', password: 'abc' });
      validate({ body: schemas.registerSchema })(req, res, next);
      expect(res.status).toHaveBeenCalledWith(400);
      const json = res.json.mock.calls[0][0];
      expect(json.details.some(d => d.field.includes('password'))).toBe(true);
    });

    test('sets default borrower_type to individual', () => {
      const { req, res, next } = mockMW({ phone: '9876543210', password: 'Test@1234' });
      validate({ body: schemas.registerSchema })(req, res, next);
      expect(req.body.borrower_type).toBe('individual');
    });

    test('rejects invalid borrower_type', () => {
      const { req, res, next } = mockMW({ phone: '9876543210', password: 'Test@1234', borrower_type: 'corporation' });
      validate({ body: schemas.registerSchema })(req, res, next);
      expect(res.status).toHaveBeenCalledWith(400);
    });
  });

  describe('consentCreateSchema', () => {
    test('passes valid consent data', () => {
      const { req, res, next } = mockMW({ signal_type: 'bank', expiry_days: 90 });
      validate({ body: schemas.consentCreateSchema })(req, res, next);
      expect(next).toHaveBeenCalled();
    });

    test('fails invalid signal_type', () => {
      const { req, res, next } = mockMW({ signal_type: 'invalid' });
      validate({ body: schemas.consentCreateSchema })(req, res, next);
      expect(res.status).toHaveBeenCalledWith(400);
    });

    test('fails invalid expiry_days', () => {
      const { req, res, next } = mockMW({ signal_type: 'bank', expiry_days: 45 });
      validate({ body: schemas.consentCreateSchema })(req, res, next);
      expect(res.status).toHaveBeenCalledWith(400);
    });

    test('sets default expiry_days to 90', () => {
      const { req, res, next } = mockMW({ signal_type: 'bank' });
      validate({ body: schemas.consentCreateSchema })(req, res, next);
      expect(req.body.expiry_days).toBe(90);
    });
  });

  describe('gstVerifySchema', () => {
    test('passes valid GSTIN', () => {
      const { req, res, next } = mockMW({ gstin: '29ABCDE1234F1Z5' });
      validate({ body: schemas.gstVerifySchema })(req, res, next);
      expect(next).toHaveBeenCalled();
    });

    test('rejects invalid GSTIN', () => {
      const { req, res, next } = mockMW({ gstin: 'INVALID_GSTIN' });
      validate({ body: schemas.gstVerifySchema })(req, res, next);
      expect(res.status).toHaveBeenCalledWith(400);
    });
  });

  describe('loanApplySchema', () => {
    test('passes valid loan application', () => {
      const { req, res, next } = mockMW({ amount: 25000 });
      validate({ body: schemas.loanApplySchema })(req, res, next);
      expect(next).toHaveBeenCalled();
    });

    test('fails if amount is 0', () => {
      const { req, res, next } = mockMW({ amount: 0 });
      validate({ body: schemas.loanApplySchema })(req, res, next);
      expect(res.status).toHaveBeenCalledWith(400);
    });

    test('fails if amount is negative', () => {
      const { req, res, next } = mockMW({ amount: -5000 });
      validate({ body: schemas.loanApplySchema })(req, res, next);
      expect(res.status).toHaveBeenCalledWith(400);
    });
  });

  describe('quizSubmitSchema', () => {
    test('passes valid quiz responses', () => {
      const { req, res, next } = mockMW({ responses: { Q01: 3, Q02: 2 } });
      validate({ body: schemas.quizSubmitSchema })(req, res, next);
      expect(next).toHaveBeenCalled();
    });

    test('fails if responses missing', () => {
      const { req, res, next } = mockMW({});
      validate({ body: schemas.quizSubmitSchema })(req, res, next);
      expect(res.status).toHaveBeenCalledWith(400);
    });
  });
});
