const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth.middleware');
const { validate, schemas } = require('../middleware/validate.middleware');
const { apiLimiter, scoreLimiter } = require('../middleware/rate-limit.middleware');
const { applyForLoan, getOffers, selectOffer, recordRepayment } = require('../controllers/loan.controller');

// POST /v1/loans/apply
router.post('/apply', authenticate, apiLimiter, validate({ body: schemas.loanApplySchema }), applyForLoan);

// GET /v1/loans/offers/:applicationId
router.get('/offers/:applicationId', authenticate, apiLimiter, getOffers);

// POST /v1/loans/select
router.post('/select', authenticate, apiLimiter, validate({ body: schemas.loanSelectSchema }), selectOffer);

// POST /v1/loans/:loanId/repay
router.post('/:loanId/repay', authenticate, apiLimiter, validate({ body: schemas.repaySchema }), recordRepayment);

module.exports = router;
