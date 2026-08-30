const mlClient = require('../services/ml-client');
const vault = require('../services/vault');
const audit = require('../services/audit');
const { pgPool } = require('../config/db');

// ─── Helper: generate rich mock bank transactions ─────────────────────────────
function generateMockBankStatement() {
  const transactions = [];
  const now = new Date();
  const gigSources = ['Swiggy Technologies', 'Ola Electric', 'Zomato Ltd', 'Amazon Seller Services', 'Urban Company'];
  const expenseNarrations = ['UPI/AMAZON', 'UPI/SWIGGY', 'ATM/WITHDRAW', 'EMI/HDFC LOAN', 'UPI/GROFERS', 'NEFT/RENT'];

  for (let i = 0; i < 12; i++) {
    const date = new Date(now);
    date.setMonth(date.getMonth() - i);

    // Monthly salary/gig credit
    transactions.push({
      txnId: `TXN_CR_${i}`,
      type: 'CREDIT',
      amount: 38000 + Math.floor(Math.random() * 12000),
      narration: gigSources[i % gigSources.length],
      date: new Date(date.getFullYear(), date.getMonth(), 1).toISOString(),
    });

    // EMI debit (consistent)
    transactions.push({
      txnId: `TXN_EMI_${i}`,
      type: 'DEBIT',
      amount: 8500,
      narration: 'EMI/HDFC PERSONAL LOAN',
      date: new Date(date.getFullYear(), date.getMonth(), 5).toISOString(),
    });

    // Random expenses
    for (let j = 0; j < 3; j++) {
      transactions.push({
        txnId: `TXN_EX_${i}_${j}`,
        type: 'DEBIT',
        amount: 500 + Math.floor(Math.random() * 4000),
        narration: expenseNarrations[j % expenseNarrations.length],
        date: new Date(date.getFullYear(), date.getMonth(), 10 + j * 5).toISOString(),
      });
    }
  }
  return { transactions };
}

// ─── Helper: generate mock GST filing data ────────────────────────────────────
function generateMockGstData() {
  const filings = [];
  const now = new Date();
  for (let i = 0; i < 6; i++) {
    const d = new Date(now);
    d.setMonth(d.getMonth() - i);
    const month = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    filings.push({
      month,
      turnover: 120000 + Math.floor(Math.random() * 60000),
      on_time: Math.random() > 0.15, // 85% on-time rate
      counterparties: ['CLIENT_A', 'CLIENT_B', 'CLIENT_C'].slice(0, 1 + (i % 3)),
    });
  }
  return { filings };
}

// ─── POST /v1/score/generate ─────────────────────────────────────────────────
async function generateScore(req, res, next) {
  try {
    const userId = req.user.id;

    // 1. Get user profile
    const userRow = await pgPool.query(
      'SELECT id, phone, borrower_type, kyc_verified FROM users WHERE id = $1',
      [userId]
    );
    if (userRow.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    const user = userRow.rows[0];

    // 2. Get all active consents — no blocking, we use flags instead
    const consentCheck = await pgPool.query(
      `SELECT signal_type FROM consents
       WHERE user_id = $1 AND status = 'active' AND expires_at > NOW()`,
      [userId]
    );
    const activeSignals = consentCheck.rows.map((r) => r.signal_type);

    // 3. Map consent signals to ML connection flags
    const bankConnected = activeSignals.includes('bank');
    const gstConnected  = activeSignals.includes('gst');
    const kycVerified   = user.kyc_verified === true || activeSignals.includes('kyc');

    // 4. Generate mock data only for connected sources (mirrors what real AA/GSP would return)
    const bankStatement = bankConnected ? generateMockBankStatement() : { transactions: [] };
    const gstData       = gstConnected  ? generateMockGstData()       : null;

    // 5. Pull latest quiz responses
    const quizRow = await pgPool.query(
      `SELECT responses, score_raw FROM quiz_responses WHERE user_id = $1 ORDER BY submitted_at DESC LIMIT 1`,
      [userId]
    );
    const quizData = quizRow.rows.length > 0 ? quizRow.rows[0] : null;
    const quizResponses = [];
    if (quizData && quizData.responses) {
      for (const [qId, ans] of Object.entries(quizData.responses)) {
        quizResponses.push({ question_id: qId, answer: ans });
      }
    }

    // 6. Assemble ML service payload with connection flags
    const mlPayload = {
      borrower_id:    userId,
      borrower_type:  user.borrower_type || 'individual',
      bank_statement: bankStatement,
      gst_data:       gstData,
      quiz_responses: quizResponses,
      bank_connected: bankConnected,
      gst_connected:  gstConnected,
      kyc_verified:   kycVerified,
    };

    // 7. Call ML service
    const scoreResponse = await mlClient.generateScore(mlPayload);

    // 8. Store score in Postgres
    const scoreResult = await pgPool.query(
      `INSERT INTO scores
         (user_id, score_value, risk_band, max_eligible_amount, signal_contributions, raw_response)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [
        userId,
        scoreResponse.score_value,
        scoreResponse.risk_band,
        scoreResponse.max_eligible_amount,
        JSON.stringify(scoreResponse.signal_contributions),
        JSON.stringify(scoreResponse),
      ]
    );
    const storedScore = scoreResult.rows[0];

    await audit.log({
      user_id: userId,
      action: 'SCORE_GENERATE',
      resource: 'scores',
      metadata: {
        score_id:          storedScore.id,
        score_value:       storedScore.score_value,
        risk_band:         storedScore.risk_band,
        bank_connected:    bankConnected,
        gst_connected:     gstConnected,
        kyc_verified:      kycVerified,
        sources_connected: scoreResponse.sources_connected || 0,
        is_mock:           scoreResponse.is_mock || false,
      },
    });

    return res.json({
      score_id:             storedScore.id,
      score_value:          storedScore.score_value,
      risk_band:            storedScore.risk_band,
      max_eligible_amount:  storedScore.max_eligible_amount,
      signal_contributions: storedScore.signal_contributions,
      npa_probability:      scoreResponse.npa_probability,
      explanation:          scoreResponse.explanation,
      generated_at:         storedScore.generated_at,
      sources_connected:    scoreResponse.sources_connected || 0,
      score_ceiling:        scoreResponse.score_ceiling || 850,
      confidence_band:      scoreResponse.confidence_band,
      stress_profile:       scoreResponse.stress_profile,
      is_mock:              scoreResponse.is_mock || false,
    });
  } catch (err) {
    next(err);
  }
}

module.exports = { generateScore };
