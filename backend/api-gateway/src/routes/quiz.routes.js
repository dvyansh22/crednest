const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth.middleware');
const { requireConsent } = require('../middleware/consent.middleware');
const { validate, schemas } = require('../middleware/validate.middleware');
const { apiLimiter, scoreLimiter } = require('../middleware/rate-limit.middleware');
const { getQuestions, submitQuiz } = require('../controllers/quiz.controller');

// GET /v1/quiz/questions — no auth needed to see questions
router.get('/questions', getQuestions);

// POST /v1/quiz/submit — requires auth + quiz consent
router.post('/submit', authenticate, requireConsent('quiz'), apiLimiter,
  validate({ body: schemas.quizSubmitSchema }), submitQuiz);

module.exports = router;
