const axios = require('axios');
const config = require('../../config/env');

const http = axios.create({ baseURL: config.mlServiceUrl, timeout: 30000 });

/**
 * Call ML service POST /v1/score or return a mock if USE_MOCK_ML_SERVICE=true.
 */
async function generateScore(payload) {
  if (config.useMockMlService) {
    return buildMockScoreResponse(payload);
  }
  try {
    const response = await http.post('/v1/score', payload);
    return response.data;
  } catch (err) {
    if (err.code === 'ECONNREFUSED' || err.code === 'ETIMEDOUT') {
      console.warn('[ML] ML service unreachable, falling back to mock');
      return buildMockScoreResponse(payload);
    }
    if (err.response) {
      const e = new Error(err.response.data?.message || 'ML service error');
      e.status = err.response.status;
      throw e;
    }
    throw err;
  }
}

/**
 * Mock ML score response — matches the schema described in API Gateway SRS §5.1.
 * Documents assumptions in docs/integration-notes.md.
 */
function buildMockScoreResponse(payload) {
  const base = 580;
  const variance = Math.floor(Math.random() * 200) - 50;
  const score = Math.max(300, Math.min(900, base + variance));

  const riskBand = score >= 720 ? 'LOW' : score >= 580 ? 'MEDIUM' : 'HIGH';
  const maxAmount = score >= 720 ? 100000 : score >= 580 ? 50000 : 25000;

  return {
    score_id:            `MOCK_SCORE_${Date.now()}`,
    user_id:             payload.user_id,
    score_value:         score,
    risk_band:           riskBand,
    max_eligible_amount: maxAmount,
    confidence:          0.82,
    signal_contributions: [
      { signal: 'bank_statements',   weight: 0.35, contribution: score * 0.35 },
      { signal: 'gst_data',          weight: 0.20, contribution: score * 0.20 },
      { signal: 'psychometric_quiz', weight: 0.25, contribution: score * 0.25 },
      { signal: 'upi_behavior',      weight: 0.20, contribution: score * 0.20 },
    ],
    npa_probability: riskBand === 'HIGH' ? 0.35 : riskBand === 'MEDIUM' ? 0.12 : 0.04,
    explanation: `Mock score generated (USE_MOCK_ML_SERVICE=true). Risk band: ${riskBand}.`,
    generated_at: new Date().toISOString(),
    is_mock: true,
  };
}

module.exports = { generateScore };
