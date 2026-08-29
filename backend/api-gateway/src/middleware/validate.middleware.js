const { z } = require('zod');

/**
 * Zod request validation middleware factory.
 * Usage: validate({ body: schema }) or validate({ params: schema, query: schema })
 */
function validate(schemas) {
  return (req, res, next) => {
    const errors = [];

    for (const [target, schema] of Object.entries(schemas)) {
      const result = schema.safeParse(req[target]);
      if (!result.success) {
        for (const issue of result.error.issues) {
          errors.push({ field: `${target}.${issue.path.join('.')}`, message: issue.message });
        }
      } else {
        // Replace with coerced/transformed values from Zod
        req[target] = result.data;
      }
    }

    if (errors.length > 0) {
      return res.status(400).json({ error: 'Validation failed', details: errors });
    }
    next();
  };
}

// ── Reusable schemas ──────────────────────────────────────────────────────────

const registerSchema = z.object({
  phone: z.string().min(10).max(15).regex(/^\d+$/, 'Phone must be digits only'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  email: z.string().email().optional(),
  full_name: z.string().max(255).optional(),
  borrower_type: z.enum(['individual', 'msme']).default('individual'),
});

const loginSchema = z.object({
  phone: z.string().min(10),
  password: z.string().min(1),
});

const refreshSchema = z.object({
  refresh_token: z.string().min(1),
});

const logoutSchema = z.object({
  refresh_token: z.string().min(1),
});

const consentCreateSchema = z.object({
  signal_type: z.enum(['bank', 'gst', 'location', 'quiz', 'digilocker']),
  expiry_days: z.coerce.number().refine((v) => [30, 90, 180].includes(v), {
    message: 'expiry_days must be 30, 90, or 180',
  }).default(90),
  consent_artifact_id: z.string().optional(),
  setu_request_id: z.string().optional(),
});

const quizSubmitSchema = z.object({
  responses: z.record(z.string(), z.coerce.number().min(1).max(4)),
});

const loanApplySchema = z.object({
  amount: z.coerce.number().positive('amount must be positive'),
  purpose: z.string().max(500).optional(),
  ladder_tier: z.coerce.number().int().min(1).max(5).optional(),
});

const loanSelectSchema = z.object({
  application_id: z.string().uuid('application_id must be a UUID'),
  offer_id: z.string().uuid('offer_id must be a UUID'),
});

const repaySchema = z.object({
  amount: z.coerce.number().positive('amount must be positive'),
});

const gstVerifySchema = z.object({
  gstin: z.string().regex(
    /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/,
    'Invalid GSTIN format'
  ),
});

const gstFetchSchema = z.object({
  gstin: z.string().regex(/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/, 'Invalid GSTIN format'),
  from_period: z.string().regex(/^\d{6}$/, 'from_period must be YYYYMM').optional(),
  to_period: z.string().regex(/^\d{6}$/, 'to_period must be YYYYMM').optional(),
});

const aaFetchSchema = z.object({
  fi_types: z.array(z.string()).min(1).optional(),
  date_range_from: z.string().datetime({ offset: true }).optional(),
  date_range_to: z.string().datetime({ offset: true }).optional(),
});

module.exports = {
  validate,
  schemas: {
    registerSchema,
    loginSchema,
    refreshSchema,
    logoutSchema,
    consentCreateSchema,
    quizSubmitSchema,
    loanApplySchema,
    loanSelectSchema,
    repaySchema,
    gstVerifySchema,
    gstFetchSchema,
    aaFetchSchema,
  },
};
