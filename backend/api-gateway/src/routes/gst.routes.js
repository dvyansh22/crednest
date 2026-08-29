const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth.middleware');
const { requireConsent } = require('../middleware/consent.middleware');
const { validate, schemas } = require('../middleware/validate.middleware');
const { apiLimiter } = require('../middleware/rate-limit.middleware');
const { verifyGstin, fetchGst } = require('../controllers/gst.controller');

// POST /v1/gst/verify
router.post('/verify', authenticate, apiLimiter, validate({ body: schemas.gstVerifySchema }), verifyGstin);

// POST /v1/gst/fetch — requires active gst consent
router.post('/fetch', authenticate, requireConsent('gst'), apiLimiter,
  validate({ body: schemas.gstFetchSchema }), fetchGst);

module.exports = router;
