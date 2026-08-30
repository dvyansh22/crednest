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
 * Mock ML score response — connection-aware, mirrors real ML service output shape.
 */
function buildMockScoreResponse(payload) {
  const bankConnected = payload.bank_connected || false;
  const gstConnected  = payload.gst_connected  || false;
  const kycVerified   = payload.kyc_verified   || false;
  const quizConnected = Array.isArray(payload.quiz_responses) && payload.quiz_responses.length > 0;

  const sourcesConnected = [bankConnected, gstConnected, kycVerified, quizConnected].filter(Boolean).length;

  const ceilings = [400, 620, 720, 790, 850];
  const scoreCeiling = ceilings[sourcesConnected] || 400;

  // Base score climbs with each connected source
  let base = 300;
  if (bankConnected) base += 180 + Math.floor(Math.random() * 80);
  if (gstConnected)  base += 60  + Math.floor(Math.random() * 40);
  if (kycVerified)   base += 50  + Math.floor(Math.random() * 30);
  if (quizConnected) base += 40  + Math.floor(Math.random() * 20);

  const score = Math.max(300, Math.min(scoreCeiling, base));
  const riskBand = score >= 750 ? 'P1' : score >= 650 ? 'P2' : score >= 550 ? 'P3' : 'P4';
  const maxAmount = score >= 750 && kycVerified ? 200000 : score >= 720 ? 100000 : score >= 580 ? 50000 : 25000;

  const signalContributions = [
    bankConnected
      ? { signal: 'bank_financial_data', label: 'Bank Account', connected: true, weight: 0.50, contribution: Math.floor(score * 0.50), impact: `+${Math.floor(score * 0.50)}` }
      : { signal: 'bank_financial_data', label: 'Bank Account', connected: false, weight: 0.50, contribution: 0, impact: 'Not connected — Connect to unlock income analysis' },
    gstConnected
      ? { signal: 'gst_filing_data', label: 'GST Data', connected: true, weight: 0.20, contribution: Math.floor(score * 0.20), impact: `+${Math.floor(score * 0.20)}` }
      : { signal: 'gst_filing_data', label: 'GST Data', connected: false, weight: 0.20, contribution: 0, impact: 'Not connected — Connect to verify business activity' },
    kycVerified
      ? { signal: 'kyc_identity', label: 'KYC Verification', connected: true, weight: 0.15, contribution: Math.floor(score * 0.15), impact: `+${Math.floor(score * 0.15)} (trust multiplier active)` }
      : { signal: 'kyc_identity', label: 'KYC Verification', connected: false, weight: 0.15, contribution: 0, impact: 'Not verified — Complete KYC to boost trust score' },
    quizConnected
      ? { signal: 'psychometric_quiz', label: 'Psychometric Assessment', connected: true, weight: 0.15, contribution: Math.floor(score * 0.15), impact: `+${Math.floor(score * 0.15)}` }
      : { signal: 'psychometric_quiz', label: 'Psychometric Assessment', connected: false, weight: 0.15, contribution: 0, impact: 'Not completed — Take quiz to add behavioural signal' },
  ];

  const narratives = {
    0: 'No data sources connected. Connect your bank account, GST data, and complete KYC verification to build your credit profile.',
    1: bankConnected ? 'Income and transaction patterns assessed using bank data. Add GST filing and KYC verification to strengthen your profile.' : 'Partial profile assessed. Connect your bank account to enable full income analysis.',
    2: 'Two data sources active. Connect remaining sources for a complete profile and higher credit ceiling.',
    3: 'Comprehensive profile assessed. Complete the psychometric assessment to add a behavioural character signal.',
    4: 'Full financial profile assessed — bank transactions, GST business activity, verified identity, and psychometric character signals all contributing.',
  };

  return {
    score_id:             `MOCK_SCORE_${Date.now()}`,
    score_value:          score,
    risk_band:            riskBand,
    max_eligible_amount:  maxAmount,
    confidence:           parseFloat((0.55 + sourcesConnected * 0.10).toFixed(2)),
    signal_contributions: signalContributions,
    npa_probability:      riskBand === 'P4' ? 0.35 : riskBand === 'P3' ? 0.12 : 0.04,
    explanation:          narratives[sourcesConnected] || narratives[0],
    generated_at:         new Date().toISOString(),
    sources_connected:    sourcesConnected,
    score_ceiling:        scoreCeiling,
    confidence_band:      [Math.max(300, score - 35), Math.min(scoreCeiling, score + 28)],
    stress_profile:       { adverse_income_score: Math.max(300, score - 42), min_emi_floor: 900 },
    is_mock:              true,
  };
}

module.exports = { generateScore };
