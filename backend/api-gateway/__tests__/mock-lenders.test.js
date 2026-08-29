/**
 * Unit tests for mock lenders OCEN module.
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

const { getMockOffers } = require('../src/services/ocen-client/mock-lenders');

describe('Mock Lenders', () => {
  const baseApp = {
    applicationId: 'test-app-001',
    requestedAmount: 25000,
    scoreValue: 680,
    riskBand: 'MEDIUM',
  };

  test('returns 3 offers for MEDIUM risk band', () => {
    const offers = getMockOffers(baseApp);
    expect(offers).toHaveLength(3);
  });

  test('returns 4 offers for LOW risk band', () => {
    const offers = getMockOffers({ ...baseApp, riskBand: 'LOW', scoreValue: 750 });
    expect(offers).toHaveLength(4);
  });

  test('returns 2 offers for HIGH risk band', () => {
    const offers = getMockOffers({ ...baseApp, riskBand: 'HIGH', scoreValue: 520 });
    expect(offers).toHaveLength(2);
  });

  test('each offer has required OCEN fields', () => {
    const offers = getMockOffers(baseApp);
    for (const offer of offers) {
      expect(offer).toHaveProperty('offerId');
      expect(offer).toHaveProperty('lenderId');
      expect(offer).toHaveProperty('loanAmount');
      expect(offer).toHaveProperty('interestRate');
      expect(offer).toHaveProperty('tenureMonths');
      expect(offer).toHaveProperty('emiAmount');
      expect(offer).toHaveProperty('processingFee');
      expect(offer).toHaveProperty('totalRepayable');
      expect(offer).toHaveProperty('validTill');
      expect(offer.currency).toBe('INR');
      expect(offer.interestType).toBe('REDUCING_BALANCE');
    }
  });

  test('interest rates are reasonable (12-30%)', () => {
    const offers = getMockOffers(baseApp);
    for (const offer of offers) {
      expect(offer.interestRate).toBeGreaterThanOrEqual(12);
      expect(offer.interestRate).toBeLessThanOrEqual(30);
    }
  });

  test('EMI is positive and less than total loan amount', () => {
    const offers = getMockOffers(baseApp);
    for (const offer of offers) {
      expect(offer.emiAmount).toBeGreaterThan(0);
      expect(offer.totalRepayable).toBeGreaterThan(offer.loanAmount);
    }
  });
});
