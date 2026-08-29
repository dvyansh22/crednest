const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth.middleware');
const { validate, schemas } = require('../middleware/validate.middleware');
const { apiLimiter } = require('../middleware/rate-limit.middleware');
const { createConsent, listConsents, revokeConsent } = require('../controllers/consent.controller');

router.use(authenticate);
router.use(apiLimiter);

// POST /v1/consent
router.post('/', validate({ body: schemas.consentCreateSchema }), createConsent);

// GET /v1/consent/:userId
router.get('/:userId', listConsents);

// DELETE /v1/consent/:consentId
router.delete('/:consentId', revokeConsent);

module.exports = router;
