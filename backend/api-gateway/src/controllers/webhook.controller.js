const { pgPool } = require('../config/db');
const audit = require('../services/audit');

// ─── POST /v1/webhooks/aa/consent ─────────────────────────────────────────────
// Setu AA webhook — consent approved/rejected notification
async function aaConsentWebhook(req, res, next) {
  try {
    const { consentHandle, status, timestamp } = req.body;

    if (!consentHandle) return res.status(400).json({ error: 'consentHandle required' });

    const pgStatus = status === 'ACTIVE' ? 'active' : status === 'REJECTED' ? 'revoked' : 'pending';

    const result = await pgPool.query(
      `UPDATE consents SET status = $1, updated_at = NOW()
       WHERE consent_artifact_id = $2
       RETURNING user_id, signal_type`,
      [pgStatus, consentHandle]
    );

    if (result.rows.length > 0) {
      await audit.log({
        user_id: result.rows[0].user_id,
        action: 'AA_CONSENT_WEBHOOK',
        resource: 'consents',
        metadata: { consentHandle, status: pgStatus, signal_type: result.rows[0].signal_type },
      });
    }

    return res.json({ received: true, consentHandle, status: pgStatus });
  } catch (err) {
    next(err);
  }
}

// ─── POST /v1/webhooks/digilocker ─────────────────────────────────────────────
// Setu DigiLocker webhook — forwards to onboarding callback handler
async function digilockerWebhook(req, res, next) {
  try {
    const { requestId, status, kycData } = req.body;
    if (!requestId) return res.status(400).json({ error: 'requestId required' });

    const stored = await pgPool.query(
      'SELECT user_id FROM digilocker_requests WHERE request_id = $1',
      [requestId]
    );
    if (stored.rows.length === 0) return res.status(404).json({ error: 'Unknown requestId' });

    const userId = stored.rows[0].user_id;
    await pgPool.query(
      `UPDATE digilocker_requests SET status = $1, kyc_data = $2, updated_at = NOW()
       WHERE request_id = $3`,
      [status, JSON.stringify(kycData || {}), requestId]
    );

    if (status === 'approved' && kycData) {
      await pgPool.query(
        `UPDATE users SET aadhaar_masked = $1, pan = $2,
         full_name = COALESCE($3, full_name),
         kyc_verified = true, kyc_verified_at = NOW(), updated_at = NOW()
         WHERE id = $4`,
        [kycData.aadhaar_masked, kycData.pan, kycData.full_name, userId]
      );
    }

    await audit.log({
      user_id: userId,
      action: 'DIGILOCKER_WEBHOOK',
      resource: 'digilocker_requests',
      metadata: { requestId, status },
    });

    return res.json({ received: true });
  } catch (err) {
    next(err);
  }
}

module.exports = { aaConsentWebhook, digilockerWebhook };
