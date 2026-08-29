const { pgPool } = require('../config/db');

// ─── GET /v1/ledger/:userId ───────────────────────────────────────────────────
async function getLedger(req, res, next) {
  try {
    const { userId } = req.params;

    // Users can only view their own ledger
    if (userId !== req.user.id) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const scoreRow = await pgPool.query(
      `SELECT id, score_value, risk_band, signal_contributions, generated_at
       FROM scores WHERE user_id = $1 ORDER BY generated_at DESC LIMIT 1`,
      [userId]
    );

    if (scoreRow.rows.length === 0) {
      return res.status(404).json({ error: 'No score found for this user' });
    }
    const score = scoreRow.rows[0];

    // Format signal_contributions as data benefit ledger
    const contributions = Array.isArray(score.signal_contributions)
      ? score.signal_contributions
      : JSON.parse(score.signal_contributions || '[]');

    return res.json({
      user_id: userId,
      score_id: score.id,
      score_value: score.score_value,
      risk_band: score.risk_band,
      generated_at: score.generated_at,
      data_benefit_ledger: contributions.map((c) => ({
        signal:       c.signal,
        weight:       c.weight,
        contribution: c.contribution,
        percentage:   ((c.weight || 0) * 100).toFixed(1) + '%',
      })),
    });
  } catch (err) {
    next(err);
  }
}

module.exports = { getLedger };
