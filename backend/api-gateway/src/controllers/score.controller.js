const mlClient = require('../services/ml-client');
const vault = require('../services/vault');
const audit = require('../services/audit');
const { pgPool } = require('../config/db');

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

    // 2. Verify required consents
    const consentCheck = await pgPool.query(
      `SELECT signal_type FROM consents
       WHERE user_id = $1 AND status = 'active' AND expires_at > NOW()`,
      [userId]
    );
    const activeSignals = consentCheck.rows.map((r) => r.signal_type);

    if (!activeSignals.includes('bank')) {
      return res.status(403).json({ error: 'Active bank consent required for scoring', code: 'CONSENT_MISSING' });
    }
    if (!activeSignals.includes('quiz')) {
      return res.status(403).json({ error: 'Active quiz consent required for scoring', code: 'CONSENT_MISSING' });
    }
    if (user.borrower_type === 'msme' && !activeSignals.includes('gst')) {
      return res.status(403).json({ error: 'Active GST consent required for MSME scoring', code: 'CONSENT_MISSING' });
    }

    // 3. Pull latest AA data refs from storage
    const aaRefs = await pgPool.query(
      `SELECT vault_key, fi_type FROM aa_data_refs WHERE user_id = $1 ORDER BY fetched_at DESC LIMIT 5`,
      [userId]
    );
    const aaData = aaRefs.rows.map((ref) => {
      try { return vault.retrieve(ref.vault_key); } catch { return null; }
    }).filter(Boolean);

    // 4. Pull GST data if MSME
    let gstData = null;
    if (user.borrower_type === 'msme') {
      const gstRef = await pgPool.query(
        `SELECT vault_key FROM aa_data_refs WHERE user_id = $1 AND fi_type = 'GST' ORDER BY fetched_at DESC LIMIT 1`,
        [userId]
      );
      if (gstRef.rows.length > 0) {
        try { gstData = vault.retrieve(gstRef.rows[0].vault_key); } catch {}
      }
    }

    // 5. Pull latest quiz responses
    const quizRow = await pgPool.query(
      `SELECT responses, score_raw FROM quiz_responses WHERE user_id = $1 ORDER BY submitted_at DESC LIMIT 1`,
      [userId]
    );
    const quizData = quizRow.rows.length > 0 ? quizRow.rows[0] : null;

    // 6. Assemble ML service payload
    const mlPayload = {
      user_id:        userId,
      borrower_type:  user.borrower_type,
      bank_data:      aaData,
      gst_data:       gstData,
      psychometric: {
        responses:  quizData?.responses || {},
        score_raw:  quizData?.score_raw || null,
      },
      kyc_verified: user.kyc_verified,
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
        score_id:    storedScore.id,
        score_value: storedScore.score_value,
        risk_band:   storedScore.risk_band,
        is_mock:     scoreResponse.is_mock || false,
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
      is_mock:              scoreResponse.is_mock || false,
    });
  } catch (err) {
    next(err);
  }
}

module.exports = { generateScore };
