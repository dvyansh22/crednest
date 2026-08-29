const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth.middleware');
const { initiate, getStatus, callback } = require('../controllers/onboarding.controller');

// POST /v1/onboarding/digilocker/initiate
router.post('/digilocker/initiate', authenticate, initiate);

// GET /v1/onboarding/digilocker/status/:requestId
router.get('/digilocker/status/:requestId', authenticate, getStatus);

// POST /v1/onboarding/digilocker/callback  (Setu webhook — no auth token)
router.post('/digilocker/callback', callback);

module.exports = router;
