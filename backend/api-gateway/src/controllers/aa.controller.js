const aaClient = require('../services/aa-client');
const vault = require('../services/vault');
const audit = require('../services/audit');
const { pgPool } = require('../config/db');

const CALLBACK_BASE = process.env.API_GATEWAY_BASE_URL || 'http://localhost:4000';

// ─── POST /v1/aa/consent/initiate ────────────────────────────────────────────
async function initiateConsent(req, res, next) {
  try {
    const userId = req.user.id;
    const { fi_types = ['DEPOSIT'], date_range_from, date_range_to } = req.body;

    const redirectUrl = `${CALLBACK_BASE}/v1/webhooks/aa/consent`;
    const result = await aaClient.initiateConsent({
      userId,
      fiTypes: fi_types,
      dateRangeFrom: date_range_from,
      dateRangeTo: date_range_to,
      redirectUrl,
    });

    // Store consent handle in consents table
    const expiresAt = new Date(Date.now() + 90 * 24 * 60 * 60 * 1000);
    await pgPool.query(
      `INSERT INTO consents (user_id, signal_type, status, expires_at, consent_artifact_id)
       VALUES ($1, 'bank', 'pending', $2, $3)
       ON CONFLICT DO NOTHING`,
      [userId, expiresAt, result.consentHandle]
    );

    await audit.log({
      user_id: userId,
      action: 'AA_CONSENT_INITIATE',
      resource: 'aa_consents',
      metadata: { consentHandle: result.consentHandle, fi_types },
    });

    return res.json({ consentHandle: result.consentHandle, redirectUrl: result.redirectUrl });
  } catch (err) {
    next(err);
  }
}

// ─── POST /v1/aa/fetch ───────────────────────────────────────────────────────
async function fetchData(req, res, next) {
  try {
    const userId = req.user.id;
    const { fi_types = ['DEPOSIT'], date_range_from, date_range_to } = req.body;

    // Get active bank consent handle
    const consentRow = await pgPool.query(
      `SELECT consent_artifact_id FROM consents
       WHERE user_id = $1 AND signal_type = 'bank' AND status = 'active'
       ORDER BY granted_at DESC LIMIT 1`,
      [userId]
    );
    if (consentRow.rows.length === 0 || !consentRow.rows[0].consent_artifact_id) {
      return res.status(400).json({ error: 'No active bank consent with handle found. Run AA consent initiate first.' });
    }
    const consentHandle = consentRow.rows[0].consent_artifact_id;

    const fiData = await aaClient.fetchData({ consentHandle, fiTypes: fi_types, dateRangeFrom: date_range_from, dateRangeTo: date_range_to });

    // Encrypt and store in vault per FI type
    const refs = [];
    for (const fiObj of fiData) {
      const vaultKey = vault.store(fiObj);
      const result = await pgPool.query(
        `INSERT INTO aa_data_refs (user_id, fi_type, vault_key, data_range_from, data_range_to)
         VALUES ($1, $2, $3, $4, $5) RETURNING id`,
        [userId, fiObj.fipID || fi_types[0], vaultKey, date_range_from || null, date_range_to || null]
      );
      refs.push({ id: result.rows[0].id, vault_key: vaultKey, fi_type: fiObj.fipID || fi_types[0] });
    }

    await audit.log({
      user_id: userId,
      action: 'AA_DATA_FETCH',
      resource: 'aa_data_refs',
      metadata: { fi_types, refCount: refs.length },
    });

    return res.json({ message: 'AA data fetched and stored', data_refs: refs });
  } catch (err) {
    next(err);
  }
}

// ─── POST /v1/aa/refresh/:userId ─────────────────────────────────────────────
async function refreshData(req, res, next) {
  try {
    const { userId } = req.params;
    // Re-use fetch logic — called by NPA job
    req.user = req.user || { id: userId };
    return fetchData(req, res, next);
  } catch (err) {
    next(err);
  }
}

module.exports = { initiateConsent, fetchData, refreshData };
