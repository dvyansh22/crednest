const { pgPool } = require('../config/db');
const digilocker = require('../services/digilocker-client');
const audit = require('../services/audit');

const CALLBACK_BASE = process.env.API_GATEWAY_BASE_URL || 'http://localhost:4000';

// ─── POST /v1/onboarding/digilocker/initiate ─────────────────────────────────
async function initiate(req, res, next) {
  try {
    const userId = req.user.id;
    const redirectBackUrl = `${CALLBACK_BASE}/v1/onboarding/digilocker/callback`;

    const { requestId, redirectUrl } = await digilocker.initiateRequest(userId, redirectBackUrl);

    // Store the pending request
    await pgPool.query(
      `INSERT INTO digilocker_requests (user_id, request_id, status, redirect_url)
       VALUES ($1, $2, 'pending', $3)
       ON CONFLICT (request_id) DO UPDATE SET status = 'pending', updated_at = NOW()`,
      [userId, requestId, redirectUrl]
    );

    await audit.log({
      user_id: userId,
      action: 'DIGILOCKER_INITIATE',
      resource: 'digilocker_requests',
      metadata: { requestId },
    });

    return res.json({ requestId, redirectUrl });
  } catch (err) {
    next(err);
  }
}

// ─── GET /v1/onboarding/digilocker/status/:requestId ─────────────────────────
async function getStatus(req, res, next) {
  try {
    const { requestId } = req.params;
    const userId = req.user.id;

    const stored = await pgPool.query(
      'SELECT * FROM digilocker_requests WHERE request_id = $1 AND user_id = $2',
      [requestId, userId]
    );
    if (stored.rows.length === 0) {
      return res.status(404).json({ error: 'DigiLocker request not found' });
    }

    // Poll Setu for latest status
    const setuStatus = await digilocker.getRequestStatus(requestId);

    // If approved, store KYC data
    if (setuStatus.status === 'approved' && setuStatus.kycData) {
      const { full_name, aadhaar_masked, pan } = setuStatus.kycData;
      await pgPool.query(
        `UPDATE digilocker_requests SET status = 'approved', kyc_data = $1, updated_at = NOW()
         WHERE request_id = $2`,
        [JSON.stringify(setuStatus.kycData), requestId]
      );
      // Update user KYC fields
      await pgPool.query(
        `UPDATE users SET aadhaar_masked = $1, pan = $2, full_name = COALESCE($3, full_name),
         kyc_verified = true, kyc_verified_at = NOW(), updated_at = NOW()
         WHERE id = $4`,
        [aadhaar_masked, pan, full_name, userId]
      );
    }

    return res.json({ requestId, status: setuStatus.status, kycData: setuStatus.kycData || null });
  } catch (err) {
    next(err);
  }
}

// ─── POST /v1/onboarding/digilocker/callback ─────────────────────────────────
// Setu webhook — stores KYC result
async function callback(req, res, next) {
  try {
    const { requestId, status, kycData } = req.body;

    if (!requestId) return res.status(400).json({ error: 'requestId is required' });

    const stored = await pgPool.query(
      'SELECT user_id FROM digilocker_requests WHERE request_id = $1',
      [requestId]
    );
    if (stored.rows.length === 0) {
      return res.status(404).json({ error: 'Unknown request' });
    }
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
      action: 'DIGILOCKER_CALLBACK',
      resource: 'digilocker_requests',
      metadata: { requestId, status },
    });

    return res.json({ received: true });
  } catch (err) {
    next(err);
  }
}

module.exports = { initiate, getStatus, callback };
