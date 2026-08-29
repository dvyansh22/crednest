const { pgPool } = require('../config/db');
const audit = require('../services/audit');

const VALID_SIGNAL_TYPES = ['bank', 'gst', 'location', 'quiz', 'digilocker'];
const VALID_EXPIRY_DAYS = [30, 90, 180];

// ─── POST /v1/consent ─────────────────────────────────────────────────────────
async function createConsent(req, res, next) {
  try {
    const userId = req.user.id;
    const { signal_type, expiry_days = 90, consent_artifact_id, setu_request_id } = req.body;

    if (!signal_type || !VALID_SIGNAL_TYPES.includes(signal_type)) {
      return res.status(400).json({
        error: `signal_type must be one of: ${VALID_SIGNAL_TYPES.join(', ')}`,
      });
    }
    if (!VALID_EXPIRY_DAYS.includes(Number(expiry_days))) {
      return res.status(400).json({ error: 'expiry_days must be 30, 90, or 180' });
    }

    const expiresAt = new Date(Date.now() + Number(expiry_days) * 24 * 60 * 60 * 1000);

    // Revoke any previous active consent for same signal
    await pgPool.query(
      `UPDATE consents SET status = 'revoked', revoked_at = NOW()
       WHERE user_id = $1 AND signal_type = $2 AND status = 'active'`,
      [userId, signal_type]
    );

    const result = await pgPool.query(
      `INSERT INTO consents (user_id, signal_type, status, expires_at, consent_artifact_id, setu_request_id)
       VALUES ($1, $2, 'active', $3, $4, $5)
       RETURNING *`,
      [userId, signal_type, expiresAt, consent_artifact_id || null, setu_request_id || null]
    );
    const consent = result.rows[0];

    await audit.log({
      user_id: userId,
      action: 'CONSENT_GRANT',
      resource: 'consents',
      metadata: { signal_type, consent_id: consent.id, expiry_days },
    });

    return res.status(201).json({ consent });
  } catch (err) {
    next(err);
  }
}

// ─── GET /v1/consent/:userId ─────────────────────────────────────────────────
async function listConsents(req, res, next) {
  try {
    const requestedUserId = req.params.userId;
    // Users can only view their own consents
    if (requestedUserId !== req.user.id) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const result = await pgPool.query(
      `SELECT * FROM consents WHERE user_id = $1 ORDER BY granted_at DESC`,
      [requestedUserId]
    );

    return res.json({ consents: result.rows });
  } catch (err) {
    next(err);
  }
}

// ─── DELETE /v1/consent/:consentId ───────────────────────────────────────────
async function revokeConsent(req, res, next) {
  try {
    const { consentId } = req.params;
    const userId = req.user.id;

    const result = await pgPool.query(
      `UPDATE consents SET status = 'revoked', revoked_at = NOW()
       WHERE id = $1 AND user_id = $2 AND status = 'active'
       RETURNING *`,
      [consentId, userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Consent not found or already revoked' });
    }

    const consent = result.rows[0];

    await audit.log({
      user_id: userId,
      action: 'CONSENT_REVOKE',
      resource: 'consents',
      metadata: { consent_id: consentId, signal_type: consent.signal_type },
    });

    return res.json({ message: 'Consent revoked', consent });
  } catch (err) {
    next(err);
  }
}

module.exports = { createConsent, listConsents, revokeConsent };
