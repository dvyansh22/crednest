const AuditLog = require('../../models/AuditLog');

/**
 * Append an audit log entry.
 * Never throws — audit failures must not break the main request flow.
 */
async function log({ user_id, action, resource, metadata = {}, ip = null }) {
  try {
    await AuditLog.create({ user_id, action, resource, metadata, ip });
  } catch (err) {
    // Audit failures are non-fatal
    console.error('[Audit] Failed to write log:', err.message, { user_id, action });
  }
}

module.exports = { log };
