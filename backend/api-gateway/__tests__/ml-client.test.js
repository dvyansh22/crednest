/**
 * Unit tests for ML client mock response.
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
process.env.USE_MOCK_ML_SERVICE = 'true';
process.env.ML_SERVICE_URL = 'http://localhost:8000';

const { generateScore } = require('../src/services/ml-client');

describe('ML Client (Mock Mode)', () => {
  const samplePayload = {
    user_id: 'test-user-001',
    borrower_type: 'individual',
    bank_data: [{ fipID: 'MOCK_FIP', accounts: [] }],
    gst_data: null,
    psychometric: { responses: { Q01: 3 }, score_raw: 75 },
    kyc_verified: true,
  };

  test('returns a valid score response', async () => {
    const response = await generateScore(samplePayload);
    expect(response).toHaveProperty('score_value');
    expect(response).toHaveProperty('risk_band');
    expect(response).toHaveProperty('max_eligible_amount');
    expect(response).toHaveProperty('signal_contributions');
    expect(response).toHaveProperty('npa_probability');
    expect(response.is_mock).toBe(true);
  });

  test('score_value is between 300 and 900', async () => {
    for (let i = 0; i < 10; i++) {
      const r = await generateScore(samplePayload);
      expect(r.score_value).toBeGreaterThanOrEqual(300);
      expect(r.score_value).toBeLessThanOrEqual(900);
    }
  });

  test('risk_band is one of LOW/MEDIUM/HIGH', async () => {
    const r = await generateScore(samplePayload);
    expect(['LOW', 'MEDIUM', 'HIGH']).toContain(r.risk_band);
  });

  test('signal_contributions sums to ~100%', async () => {
    const r = await generateScore(samplePayload);
    const totalWeight = r.signal_contributions.reduce((sum, s) => sum + s.weight, 0);
    expect(totalWeight).toBeCloseTo(1.0, 1);
  });

  test('npa_probability is between 0 and 1', async () => {
    const r = await generateScore(samplePayload);
    expect(r.npa_probability).toBeGreaterThanOrEqual(0);
    expect(r.npa_probability).toBeLessThanOrEqual(1);
  });
});
