const { pgPool } = require('../config/db');
const { getMockOffers } = require('../services/ocen-client/mock-lenders');
const { runLadderGraduation } = require('../services/loan-ladder.service');
const audit = require('../services/audit');

// ─── POST /v1/loans/apply ─────────────────────────────────────────────────────
async function applyForLoan(req, res, next) {
  try {
    const userId = req.user.id;
    const { amount, purpose, ladder_tier } = req.body;

    if (!amount || Number(amount) <= 0) {
      return res.status(400).json({ error: 'amount is required and must be positive' });
    }

    // Get latest score
    const scoreRow = await pgPool.query(
      `SELECT id, score_value, risk_band, max_eligible_amount FROM scores
       WHERE user_id = $1 ORDER BY generated_at DESC LIMIT 1`,
      [userId]
    );
    if (scoreRow.rows.length === 0) {
      return res.status(400).json({ error: 'No credit score found. Run POST /v1/score/generate first.' });
    }
    const score = scoreRow.rows[0];

    if (Number(amount) > Number(score.max_eligible_amount)) {
      return res.status(400).json({
        error: `Requested amount ₹${amount} exceeds max eligible amount ₹${score.max_eligible_amount}`,
        max_eligible_amount: score.max_eligible_amount,
      });
    }

    // Build OCEN LoanApplicationRequest
    const ocenRequest = {
      loanApplicationId: `LA_${Date.now()}`,
      borrowerId: userId,
      loanAmount: Number(amount),
      currency: 'INR',
      purpose: purpose || 'Business working capital',
      scoreValue: score.score_value,
      riskBand: score.risk_band,
    };

    // Create loan application record
    const loanResult = await pgPool.query(
      `INSERT INTO loan_applications
         (user_id, score_id, status, amount_requested, ladder_tier, purpose, ocen_request)
       VALUES ($1, $2, 'pending', $3, $4, $5, $6)
       RETURNING *`,
      [userId, score.id, Number(amount), ladder_tier || 1, purpose || null, JSON.stringify(ocenRequest)]
    );
    const application = loanResult.rows[0];

    // Get mock offers from lenders
    const offers = getMockOffers({
      applicationId: application.id,
      requestedAmount: Number(amount),
      scoreValue: score.score_value,
      riskBand: score.risk_band,
    });

    // Update status
    await pgPool.query(
      `UPDATE loan_applications SET status = 'offers_received' WHERE id = $1`,
      [application.id]
    );

    // Cache offers in Redis
    const { redis } = require('../config/db');
    await redis.set(`offers:${application.id}`, JSON.stringify(offers), 'EX', 48 * 3600);

    await audit.log({
      user_id: userId,
      action: 'LOAN_APPLY',
      resource: 'loan_applications',
      metadata: { application_id: application.id, amount, score_value: score.score_value, offers_count: offers.length },
    });

    return res.status(201).json({
      application_id: application.id,
      status: 'offers_received',
      ocen_request: ocenRequest,
      offers_count: offers.length,
      message: `${offers.length} lender offers received. Fetch via GET /v1/loans/offers/${application.id}`,
    });
  } catch (err) {
    next(err);
  }
}

// ─── GET /v1/loans/offers/:applicationId ─────────────────────────────────────
async function getOffers(req, res, next) {
  try {
    const { applicationId } = req.params;
    const userId = req.user.id;

    const appRow = await pgPool.query(
      'SELECT * FROM loan_applications WHERE id = $1 AND user_id = $2',
      [applicationId, userId]
    );
    if (appRow.rows.length === 0) {
      return res.status(404).json({ error: 'Loan application not found' });
    }

    const { redis } = require('../config/db');
    const cached = await redis.get(`offers:${applicationId}`);
    if (!cached) {
      return res.status(404).json({ error: 'Offers expired or not found. Please re-apply.' });
    }

    const offers = JSON.parse(cached);
    // Rank by total repayable (ascending)
    offers.sort((a, b) => a.totalRepayable - b.totalRepayable);

    await audit.log({
      user_id: userId,
      action: 'LENDER_QUERY',
      resource: 'loan_offers',
      metadata: { application_id: applicationId, offers_count: offers.length },
    });

    return res.json({ application_id: applicationId, offers });
  } catch (err) {
    next(err);
  }
}

// ─── POST /v1/loans/select ────────────────────────────────────────────────────
async function selectOffer(req, res, next) {
  try {
    const userId = req.user.id;
    const { application_id, offer_id } = req.body;

    if (!application_id || !offer_id) {
      return res.status(400).json({ error: 'application_id and offer_id are required' });
    }

    const { redis } = require('../config/db');
    const cached = await redis.get(`offers:${application_id}`);
    if (!cached) return res.status(404).json({ error: 'Offers expired. Please re-apply.' });

    const offers = JSON.parse(cached);
    const selected = offers.find((o) => o.offerId === offer_id);
    if (!selected) return res.status(404).json({ error: 'Offer not found' });

    const disbursedAt = new Date();
    const dueDate = new Date(disbursedAt.getTime() + selected.tenureMonths * 30 * 24 * 60 * 60 * 1000);

    await pgPool.query(
      `UPDATE loan_applications SET
         status = 'disbursed',
         selected_offer_id = $1,
         lender_id = $2,
         interest_rate = $3,
         tenure_months = $4,
         amount_approved = $5,
         disbursed_at = $6,
         due_date = $7,
         updated_at = NOW()
       WHERE id = $8 AND user_id = $9`,
      [
        offer_id, selected.lenderId, selected.interestRate,
        selected.tenureMonths, selected.loanAmount,
        disbursedAt, dueDate, application_id, userId,
      ]
    );

    // Trigger GrantRequest (mock)
    const grantConfirmation = {
      grantId: `GRANT_${Date.now()}`,
      applicationId: application_id,
      offerId: offer_id,
      lenderId: selected.lenderId,
      lenderName: selected.lenderName,
      loanAmount: selected.loanAmount,
      interestRate: selected.interestRate,
      tenureMonths: selected.tenureMonths,
      emiAmount: selected.emiAmount,
      disbursedAt: disbursedAt.toISOString(),
      firstDueDate: new Date(disbursedAt.getTime() + 30 * 24 * 60 * 60 * 1000).toISOString(),
      status: 'DISBURSED',
    };

    await audit.log({
      user_id: userId,
      action: 'LOAN_SELECT',
      resource: 'loan_applications',
      metadata: { application_id, offer_id, lender: selected.lenderName, amount: selected.loanAmount },
    });

    return res.json({ message: 'Loan disbursed', disbursement: grantConfirmation });
  } catch (err) {
    next(err);
  }
}

// ─── POST /v1/loans/:loanId/repay ─────────────────────────────────────────────
async function recordRepayment(req, res, next) {
  try {
    const userId = req.user.id;
    const { loanId } = req.params;
    const { amount } = req.body;

    if (!amount || Number(amount) <= 0) {
      return res.status(400).json({ error: 'amount is required and must be positive' });
    }

    // Verify loan ownership
    const loanRow = await pgPool.query(
      `SELECT * FROM loan_applications WHERE id = $1 AND user_id = $2`,
      [loanId, userId]
    );
    if (loanRow.rows.length === 0) return res.status(404).json({ error: 'Loan not found' });
    const loan = loanRow.rows[0];

    if (['repaid', 'npa'].includes(loan.status)) {
      return res.status(400).json({ error: `Loan is already ${loan.status}` });
    }

    // Record repayment
    const repayResult = await pgPool.query(
      `INSERT INTO repayments (loan_id, user_id, amount, status)
       VALUES ($1, $2, $3, 'completed') RETURNING *`,
      [loanId, userId, Number(amount)]
    );

    // Check if fully repaid (sum of repayments >= approved amount)
    const totalRepaid = await pgPool.query(
      `SELECT COALESCE(SUM(amount), 0) AS total FROM repayments WHERE loan_id = $1 AND status = 'completed'`,
      [loanId]
    );
    const total = parseFloat(totalRepaid.rows[0].total);
    const approvedAmount = parseFloat(loan.amount_approved || loan.amount_requested);

    let newStatus = loan.status;
    let ladderResult = null;

    if (total >= approvedAmount) {
      newStatus = 'repaid';
      await pgPool.query(
        `UPDATE loan_applications SET status = 'repaid', updated_at = NOW() WHERE id = $1`,
        [loanId]
      );
      // Trigger micro-ladder graduation
      ladderResult = await runLadderGraduation(userId, loan);
    } else {
      await pgPool.query(
        `UPDATE loan_applications SET status = 'active', updated_at = NOW() WHERE id = $1`,
        [loanId]
      );
      newStatus = 'active';
    }

    await audit.log({
      user_id: userId,
      action: 'LOAN_REPAYMENT',
      resource: 'repayments',
      metadata: { loan_id: loanId, amount, total_repaid: total, loan_status: newStatus },
    });

    return res.json({
      repayment_id: repayResult.rows[0].id,
      loan_id: loanId,
      amount_paid: Number(amount),
      total_repaid: total,
      loan_status: newStatus,
      ...(ladderResult && { ladder_upgrade: ladderResult }),
    });
  } catch (err) {
    next(err);
  }
}

module.exports = { applyForLoan, getOffers, selectOffer, recordRepayment };
