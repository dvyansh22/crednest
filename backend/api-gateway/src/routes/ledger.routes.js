const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth.middleware');
const { getLedger } = require('../controllers/ledger.controller');

// GET /v1/ledger/:userId
router.get('/:userId', authenticate, getLedger);

module.exports = router;
