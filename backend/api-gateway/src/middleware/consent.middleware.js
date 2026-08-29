const { pgPool } = require('../config/db');

const VALID_SIGNAL_TYPES = ['bank', 'gst', 'location', 'quiz', 'digilocker'];

/**
 * requireConsent(signalType) — middleware factory.
 * Blocks the route if the authenticated user has no active, non-expired consent
 * for the given signal type.
 */
function requireConsent(signalType) {
  if (!VALID_SIGNAL_TYPES.includes(signalType)) {
    throw new Error(`Unknown signal type: ${signalType}`);
  }

  return async (req, res, next) => {
    try {
      const userId = req.user?.id;
      if (!userId) return res.status(401).json({ error: 'Unauthorized' });

      const result = await pgPool.query(
        `SELECT id, status, expires_at
         FROM consents
         WHERE user_id = $1 AND signal_type = $2
           AND status = 'active' AND expires_at > NOW()
         ORDER BY granted_at DESC LIMIT 1`,
        [userId, signalType]
      );

      if (result.rows.length === 0) {
        return res.status(403).json({
          error: `Consent required for signal: ${signalType}`,
          code: 'CONSENT_MISSING_OR_EXPIRED',
          signal_type: signalType,
        });
      }

      // Attach active consent id to request for downstream use
      req.activeConsent = result.rows[0];
      next();
    } catch (err) {
      next(err);
    }
  };
}

module.exports = { requireConsent };
