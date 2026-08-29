const mongoose = require('mongoose');

const auditLogSchema = new mongoose.Schema(
  {
    timestamp:  { type: Date, default: Date.now, index: true },
    user_id:    { type: String, index: true },
    action:     { type: String, required: true },   // e.g. CONSENT_GRANT, AA_FETCH, SCORE_GENERATE
    resource:   { type: String },                   // e.g. consents, aa_data, scores
    metadata:   { type: mongoose.Schema.Types.Mixed },
    ip:         { type: String },
  },
  {
    // append-only: disable update/delete hooks
    capped: false,
    strict: true,
    versionKey: false,
  }
);

// Prevent updates — audit logs are append-only
auditLogSchema.pre('updateOne', function () {
  throw new Error('AuditLog is append-only');
});
auditLogSchema.pre('updateMany', function () {
  throw new Error('AuditLog is append-only');
});
auditLogSchema.pre('findOneAndUpdate', function () {
  throw new Error('AuditLog is append-only');
});

module.exports = mongoose.model('AuditLog', auditLogSchema, 'audit_logs');
