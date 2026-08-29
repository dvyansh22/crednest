const express = require('express');
const router = express.Router();
const { aaConsentWebhook, digilockerWebhook } = require('../controllers/webhook.controller');

// Webhooks receive calls from Setu — no JWT auth, but in production add webhook signature verification
// POST /v1/webhooks/aa/consent
router.post('/aa/consent', aaConsentWebhook);

// POST /v1/webhooks/digilocker
router.post('/digilocker', digilockerWebhook);

module.exports = router;
