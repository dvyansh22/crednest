const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth.middleware');
const { scoreLimiter } = require('../middleware/rate-limit.middleware');
const { generateScore } = require('../controllers/score.controller');

// POST /v1/score/generate — throttled: max 5/min per user
router.post('/generate', authenticate, scoreLimiter, generateScore);

module.exports = router;
