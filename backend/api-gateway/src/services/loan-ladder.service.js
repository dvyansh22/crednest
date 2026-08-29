const { pgPool } = require('../config/db');
const mlClient = require('./ml-client');
const audit = require('./audit');

/**
 * Micro-ladder graduation logic (FR-10).
 * Called after a loan is fully repaid.
 * Automatically triggers a new loan application at a higher tier.
 */

// Ladder tiers: tier → max_amount
const LADDER_TIERS = {
  1: 10000,
  2: 25000,
  3: 50000,
  4: 100000,
  5: 200000,
};

async function runLadderGraduation(userId, completedLoan) {
  try {
    const currentTier = completedLoan.ladder_tier || 1;
    const nextTier = currentTier + 1;

    if (!LADDER_TIERS[nextTier]) {
      console.log(`[Ladder] User ${userId} is already at max tier ${currentTier}`);
      return { message: 'Already at maximum ladder tier', current_tier: currentTier };
    }

    // Check if existing consents are still valid — no re-upload needed per SRS
    const consentCheck = await pgPool.query(
      `SELECT signal_type FROM consents
       WHERE user_id = $1 AND status = 'active' AND expires_at > NOW()`,
      [userId]
    );
    const activeSignals = consentCheck.rows.map((r) => r.signal_type);

    if (!activeSignals.includes('bank')) {
      console.log(`[Ladder] User ${userId} bank consent expired — cannot auto-graduate`);
      return { message: 'Consent expired — user must re-consent to graduate', current_tier: currentTier };
    }

    // Get latest score
    const scoreRow = await pgPool.query(
      `SELECT id, score_value, risk_band, max_eligible_amount
       FROM scores WHERE user_id = $1 ORDER BY generated_at DESC LIMIT 1`,
      [userId]
    );
    if (scoreRow.rows.length === 0) {
      return { message: 'No score found for ladder graduation', current_tier: currentTier };
    }
    const score = scoreRow.rows[0];
    const nextAmount = Math.min(LADDER_TIERS[nextTier], Number(score.max_eligible_amount));

    // Create a new loan application at next tier
    const newLoan = await pgPool.query(
      `INSERT INTO loan_applications
         (user_id, score_id, status, amount_requested, ladder_tier, purpose)
       VALUES ($1, $2, 'pending', $3, $4, 'Micro-ladder auto-graduation')
       RETURNING id`,
      [userId, score.id, nextAmount, nextTier]
    );

    await audit.log({
      user_id: userId,
      action: 'LADDER_GRADUATION',
      resource: 'loan_applications',
      metadata: {
        previous_loan_id: completedLoan.id,
        previous_tier: currentTier,
        next_tier: nextTier,
        next_amount: nextAmount,
        new_application_id: newLoan.rows[0].id,
      },
    });

    console.log(`[Ladder] User ${userId} graduated to tier ${nextTier} — new application ${newLoan.rows[0].id}`);

    return {
      message: 'Congratulations! You have been upgraded to a higher loan tier.',
      current_tier: currentTier,
      next_tier: nextTier,
      next_amount: nextAmount,
      new_application_id: newLoan.rows[0].id,
    };
  } catch (err) {
    console.error('[Ladder] Graduation failed:', err.message);
    return { message: 'Ladder graduation failed (non-fatal)', error: err.message };
  }
}

module.exports = { runLadderGraduation, LADDER_TIERS };
