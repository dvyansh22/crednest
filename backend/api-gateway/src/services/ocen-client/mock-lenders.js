const { v4: uuidv4 } = require('uuid');

/**
 * Mock OCEN lender module.
 * Returns 2–4 randomized OfferResponse objects following real OCEN schema fields.
 */
const LENDERS = [
  { id: 'LENDER_FINFLOW_001',  name: 'FinFlow Capital',    baseRate: 18, tenors: [6, 12, 18] },
  { id: 'LENDER_MICROMAX_002', name: 'MicroMax Finance',   baseRate: 22, tenors: [3, 6, 12] },
  { id: 'LENDER_SAATHI_003',   name: 'Saathi Lending Co',  baseRate: 16, tenors: [12, 24, 36] },
  { id: 'LENDER_RAPIDCRED_004',name: 'RapidCred Solutions', baseRate: 20, tenors: [6, 9, 12] },
];

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

/**
 * Generate mock offers for an application.
 * @param {object} application - { applicationId, requestedAmount, scoreValue, riskBand, borrowerType }
 * @returns {OfferResponse[]}
 */
function getMockOffers(application) {
  const { applicationId, requestedAmount, scoreValue = 600, riskBand = 'MEDIUM' } = application;

  // Higher score → more lenders participate
  const numOffers = riskBand === 'LOW' ? 4 : riskBand === 'MEDIUM' ? 3 : 2;
  const selectedLenders = [...LENDERS].sort(() => Math.random() - 0.5).slice(0, numOffers);

  return selectedLenders.map((lender) => {
    const scoreBonus = Math.max(0, (scoreValue - 580) / 100) * 2; // score → rate reduction
    const interestRate = Math.max(12, lender.baseRate - scoreBonus + (Math.random() * 2 - 1));
    const tenure = pick(lender.tenors);

    // Calculate EMI
    const principal = requestedAmount;
    const monthlyRate = interestRate / 100 / 12;
    const emi = principal * monthlyRate * Math.pow(1 + monthlyRate, tenure)
                / (Math.pow(1 + monthlyRate, tenure) - 1);

    return {
      offerId:       uuidv4(),
      applicationId,
      lenderId:      lender.id,
      lenderName:    lender.name,
      // OCEN schema fields
      loanAmount:    Math.round(principal),
      currency:      'INR',
      interestRate:  parseFloat(interestRate.toFixed(2)),
      interestType:  'REDUCING_BALANCE',
      repaymentFrequency: 'MONTHLY',
      tenureMonths:  tenure,
      emiAmount:     parseFloat(emi.toFixed(2)),
      processingFee: parseFloat((principal * 0.02).toFixed(2)),  // 2% processing fee
      totalRepayable: parseFloat((emi * tenure).toFixed(2)),
      disbursalMode: 'BANK_TRANSFER',
      validTill:     new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString(), // 48h validity
      terms: {
        prepaymentAllowed: true,
        prepaymentPenalty: riskBand === 'LOW' ? 0 : 2,
        collateralRequired: false,
      },
      generatedAt: new Date().toISOString(),
    };
  });
}

module.exports = { getMockOffers };
