const gstClient = require('../services/gsp-client');
const vault = require('../services/vault');
const audit = require('../services/audit');
const { pgPool } = require('../config/db');

// ─── POST /v1/gst/verify ─────────────────────────────────────────────────────
async function verifyGstin(req, res, next) {
  try {
    const userId = req.user.id;
    const { gstin } = req.body;

    if (!gstin || !/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/.test(gstin)) {
      return res.status(400).json({ error: 'Invalid GSTIN format' });
    }

    const result = await gstClient.verifyGstin(gstin);

    await audit.log({
      user_id: userId,
      action: 'GST_VERIFY',
      resource: 'gst',
      metadata: { gstin, status: result.status },
    });

    return res.json(result);
  } catch (err) {
    next(err);
  }
}

// ─── POST /v1/gst/fetch ──────────────────────────────────────────────────────
async function fetchGst(req, res, next) {
  try {
    const userId = req.user.id;
    const { gstin, from_period, to_period } = req.body;

    if (!gstin) return res.status(400).json({ error: 'gstin is required' });

    // Only for MSME borrowers
    const userRow = await pgPool.query('SELECT borrower_type FROM users WHERE id = $1', [userId]);
    if (userRow.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    if (userRow.rows[0].borrower_type !== 'msme') {
      return res.status(403).json({ error: 'GST fetch is only available for MSME borrowers' });
    }

    const gstData = await gstClient.fetchGstReturns(
      gstin,
      from_period || '202301',
      to_period || new Date().toISOString().slice(0, 7).replace('-', '')
    );

    // Store encrypted in vault, reference in Postgres
    const vaultKey = vault.store(gstData);
    await pgPool.query(
      `INSERT INTO aa_data_refs (user_id, fi_type, vault_key)
       VALUES ($1, 'GST', $2)`,
      [userId, vaultKey]
    );

    await audit.log({
      user_id: userId,
      action: 'GST_DATA_FETCH',
      resource: 'gst',
      metadata: { gstin, from_period, to_period },
    });

    return res.json({ message: 'GST data fetched and stored', vault_key: vaultKey, summary: gstData.GSTR3B });
  } catch (err) {
    next(err);
  }
}

module.exports = { verifyGstin, fetchGst };
