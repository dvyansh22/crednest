const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth.middleware');
const { requireConsent } = require('../middleware/consent.middleware');
const { validate, schemas } = require('../middleware/validate.middleware');
const { apiLimiter } = require('../middleware/rate-limit.middleware');
const { initiateConsent, fetchData, refreshData, handleCallback } = require('../controllers/aa.controller');

// POST /v1/aa/consent/initiate
router.post('/consent/initiate', authenticate, apiLimiter, initiateConsent);

// GET /v1/aa/callback — Setu browser redirect callback
router.get('/callback', handleCallback);

// POST /v1/aa/fetch — requires active bank consent
router.post('/fetch', authenticate, requireConsent('bank'), apiLimiter,
  validate({ body: schemas.aaFetchSchema }), fetchData);

// POST /v1/aa/refresh/:userId — called by NPA job (internal)
router.post('/refresh/:userId', authenticate, refreshData);

module.exports = router;
