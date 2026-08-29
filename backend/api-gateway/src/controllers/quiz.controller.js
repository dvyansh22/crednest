const questions = require('../data/quiz-questions.json');
const { pgPool } = require('../config/db');
const audit = require('../services/audit');

// ─── GET /v1/quiz/questions ───────────────────────────────────────────────────
async function getQuestions(req, res) {
  return res.json({ questions, total: questions.length });
}

// ─── POST /v1/quiz/submit ─────────────────────────────────────────────────────
async function submitQuiz(req, res, next) {
  try {
    const userId = req.user.id;
    const { responses } = req.body; // { Q01: 3, Q02: 4, ... }

    if (!responses || typeof responses !== 'object') {
      return res.status(400).json({ error: 'responses object is required' });
    }

    // Validate all 12 questions answered
    const missing = questions.filter((q) => responses[q.id] === undefined).map((q) => q.id);
    if (missing.length > 0) {
      return res.status(400).json({ error: `Missing answers for: ${missing.join(', ')}` });
    }

    // Compute raw psychometric score (average of responses * 25 → 0–100 scale)
    const totalScore = Object.values(responses).reduce((sum, v) => sum + Number(v), 0);
    const maxPossible = questions.length * 4;
    const scoreRaw = parseFloat(((totalScore / maxPossible) * 100).toFixed(2));

    const result = await pgPool.query(
      `INSERT INTO quiz_responses (user_id, responses, score_raw)
       VALUES ($1, $2, $3) RETURNING *`,
      [userId, JSON.stringify(responses), scoreRaw]
    );

    await audit.log({
      user_id: userId,
      action: 'QUIZ_SUBMIT',
      resource: 'quiz_responses',
      metadata: { quiz_id: result.rows[0].id, score_raw: scoreRaw },
    });

    return res.status(201).json({
      message: 'Quiz submitted',
      quiz_id: result.rows[0].id,
      score_raw: scoreRaw,
      submitted_at: result.rows[0].submitted_at,
    });
  } catch (err) {
    next(err);
  }
}

module.exports = { getQuestions, submitQuiz };
