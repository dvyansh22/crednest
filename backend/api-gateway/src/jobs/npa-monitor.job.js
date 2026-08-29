const { pgPool } = require('../config/db');
const { redis } = require('../config/db');
const mlClient = require('../services/ml-client');
const vault = require('../services/vault');
const aaClient = require('../services/aa-client');
const audit = require('../services/audit');

/**
 * NPA Early Warning Monitor Job (FR-9).
 *
 * In production: This would be a Kafka consumer listening to a scheduled topic.
 * For hackathon: We use a simple setInterval that runs every 6 hours.
 *
 * Logic:
 * 1. Find all users with active loans
 * 2. Re-fetch AA data for each
 * 3. Re-score via ML service (or mock)
 * 4. Flag users whose NPA probability exceeds threshold
 */

const NPA_THRESHOLD = 0.30;       // flag if NPA probability > 30%
const CHECK_INTERVAL_MS = 6 * 60 * 60 * 1000; // 6 hours

async function runNpaCheck() {
  console.log('[NPA Monitor] Starting NPA early warning check...');
  try {
    // Get all users with active (disbursed) loans
    const activeLoans = await pgPool.query(
      `SELECT DISTINCT user_id FROM loan_applications WHERE status IN ('disbursed', 'active')`
    );

    if (activeLoans.rows.length === 0) {
      console.log('[NPA Monitor] No active loans to check');
      return;
    }

    console.log(`[NPA Monitor] Checking ${activeLoans.rows.length} users`);

    for (const { user_id } of activeLoans.rows) {
      try {
        await checkUserNpa(user_id);
      } catch (err) {
        console.error(`[NPA Monitor] Error checking user ${user_id}:`, err.message);
      }
    }

    console.log('[NPA Monitor] NPA check complete');
  } catch (err) {
    console.error('[NPA Monitor] Job error:', err.message);
  }
}

async function checkUserNpa(userId) {
  // Pull latest AA data refs
  const aaRefs = await pgPool.query(
    `SELECT vault_key, fi_type FROM aa_data_refs WHERE user_id = $1 ORDER BY fetched_at DESC LIMIT 3`,
    [userId]
  );
  const aaData = aaRefs.rows.map((ref) => {
    try { return vault.retrieve(ref.vault_key); } catch { return null; }
  }).filter(Boolean);

  // Pull latest quiz
  const quizRow = await pgPool.query(
    `SELECT responses, score_raw FROM quiz_responses WHERE user_id = $1 ORDER BY submitted_at DESC LIMIT 1`,
    [userId]
  );
  const quizData = quizRow.rows[0] || null;

  const userRow = await pgPool.query('SELECT borrower_type FROM users WHERE id = $1', [userId]);
  const borrowerType = userRow.rows[0]?.borrower_type || 'individual';

  const mlPayload = {
    user_id: userId,
    borrower_type: borrowerType,
    bank_data: aaData,
    gst_data: null,
    psychometric: { responses: quizData?.responses || {}, score_raw: quizData?.score_raw || null },
    kyc_verified: true,
  };

  const scoreResponse = await mlClient.generateScore(mlPayload);

  if (scoreResponse.npa_probability > NPA_THRESHOLD) {
    // Store alert flag in Redis
    await redis.set(
      `npa_alert:${userId}`,
      JSON.stringify({
        userId,
        npa_probability: scoreResponse.npa_probability,
        risk_band: scoreResponse.risk_band,
        flagged_at: new Date().toISOString(),
      }),
      'EX', 7 * 24 * 3600 // 7 days TTL
    );

    await audit.log({
      user_id: userId,
      action: 'NPA_ALERT_FLAGGED',
      resource: 'scores',
      metadata: {
        npa_probability: scoreResponse.npa_probability,
        risk_band: scoreResponse.risk_band,
        score_value: scoreResponse.score_value,
      },
    });

    console.warn(`[NPA Monitor] ALERT — User ${userId} NPA probability: ${scoreResponse.npa_probability.toFixed(2)}`);
  }
}

let _jobInterval = null;

async function startNpaMonitor() {
  // Run once on startup (delayed by 1 min so DBs are fully ready)
  setTimeout(runNpaCheck, 60 * 1000);

  // Then run every 6 hours
  _jobInterval = setInterval(runNpaCheck, CHECK_INTERVAL_MS);
  console.log('[NPA Monitor] Scheduled — runs every 6 hours');
}

function stopNpaMonitor() {
  if (_jobInterval) clearInterval(_jobInterval);
}

module.exports = { startNpaMonitor, stopNpaMonitor, runNpaCheck };
