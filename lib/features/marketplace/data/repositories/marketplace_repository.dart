import 'package:flutter/material.dart';

import '../models/loan_application_model.dart';
import '../models/loan_offer_model.dart';

/// Supplies loan offers and handles applications. No backend/OCEN/LSP
/// integration exists yet — every method here returns data shaped like the
/// eventual API response. Swap bodies for real calls without touching any
/// caller:
///   getLoanOffers        -> GET /loan-offers
///   getLoanOfferById     -> GET /loan-offers/{id}
///   submitLoanApplication -> POST /loan-applications (routed to OCEN/LSP
///                             by the backend, not from this app)
///   getApplicationStatus -> GET /loan-applications/{id}
class MarketplaceRepository {
  final Map<String, LoanApplication> _applications = {};

  Future<List<LoanOffer>> getLoanOffers() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _demoOffers;
  }

  Future<LoanOffer?> getLoanOfferById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    for (final offer in _demoOffers) {
      if (offer.id == id) return offer;
    }
    return null;
  }

  /// [consentIds] are references to already-granted consents, not the
  /// underlying financial data itself — the backend resolves them.
  Future<LoanApplication> submitLoanApplication({
    required String userId,
    required String offerId,
    required double requestedAmount,
    required int? creditDnaScore,
    required List<String> consentIds,
  }) async {
    // TODO(backend): POST /loan-applications — send userId, offerId,
    // requestedAmount, creditDnaScore, consentIds. The backend is
    // responsible for any OCEN/LSP/lender submission from here.
    await Future.delayed(const Duration(seconds: 2));

    final now = DateTime.now();
    final applicationId = 'CN-${now.year}-${(now.millisecondsSinceEpoch % 100000).toString().padLeft(5, '0')}';

    final application = LoanApplication(
      applicationId: applicationId,
      userId: userId,
      offerId: offerId,
      requestedAmount: requestedAmount,
      status: LoanApplicationStatus.submitted,
      submittedAt: now,
    );

    _applications[applicationId] = application;
    return application;
  }

  /// TEMPORARY: simulates status progressing over time purely so the
  /// tracker has real states to render in development. Replace entirely
  /// with GET /loan-applications/{id} once a backend exists — real status
  /// will never be time-derived like this.
  Future<LoanApplication?> getApplicationStatus(String applicationId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final application = _applications[applicationId];
    if (application == null) return null;

    final elapsed = DateTime.now().difference(application.submittedAt);
    final offer = await getLoanOfferById(application.offerId);

    LoanApplicationStatus status;
    if (elapsed < const Duration(seconds: 12)) {
      status = LoanApplicationStatus.submitted;
    } else if (elapsed < const Duration(seconds: 24)) {
      status = LoanApplicationStatus.underReview;
    } else if (elapsed < const Duration(seconds: 36) || offer == null) {
      status = LoanApplicationStatus.approved;
    } else {
      status = LoanApplicationStatus.disbursed;
    }

    final updated = application.copyWith(
      status: status,
      approvedAmount: status.index >= LoanApplicationStatus.approved.index ? application.requestedAmount : null,
      finalInterestRate: status.index >= LoanApplicationStatus.approved.index ? offer?.interestRatePercent : null,
      finalEmi: status.index >= LoanApplicationStatus.approved.index ? offer?.emi : null,
      finalTenureMonths: status.index >= LoanApplicationStatus.approved.index ? offer?.tenureMonths : null,
      disbursedAt: status == LoanApplicationStatus.disbursed ? application.submittedAt.add(const Duration(seconds: 36)) : null,
      maskedAccountReference: status == LoanApplicationStatus.disbursed ? 'XXXX XXXX 1234' : null,
    );
    _applications[applicationId] = updated;
    return updated;
  }

  static const List<LoanOffer> _demoOffers = [
    LoanOffer(
      id: 'novafin-personal',
      lenderId: 'novafin',
      lenderName: 'NovaFin',
      lenderIcon: Icons.account_balance,
      lenderColor: Color(0xFF2E5FA3),
      loanType: 'Personal Loan',
      loanAmount: 200000,
      interestRatePercent: 12.5,
      tenureMonths: 24,
      processingFeePercent: 1.5,
      benefits: ['Quick approval', 'Minimal documentation'],
      eligibilityRequirements: [
        'Age between 21 and 58 years',
        'Minimum monthly income of ₹25,000',
        'At least 6 months of connected bank history',
      ],
      requiredDocuments: ['PAN card', 'Address proof', 'Bank statements (last 3 months)'],
      repaymentInformation: 'Repay via auto-debit on a fixed date each month. No prepayment penalty after 6 EMIs.',
      approvalSpeed: ApprovalSpeed.instant,
      isFeatured: true,
    ),
    LoanOffer(
      id: 'bluepeak-personal',
      lenderId: 'bluepeak',
      lenderName: 'Bluepeak Bank',
      lenderIcon: Icons.account_balance_outlined,
      lenderColor: Color(0xFF102A43),
      loanType: 'Personal Loan',
      loanAmount: 200000,
      interestRatePercent: 13.2,
      tenureMonths: 24,
      processingFeePercent: 1.0,
      benefits: ['Instant approval', 'Flexible repayment'],
      eligibilityRequirements: [
        'Age between 23 and 60 years',
        'Minimum monthly income of ₹20,000',
        'Verified identity and address',
      ],
      requiredDocuments: ['PAN card', 'Aadhaar (for address proof)', 'Bank statements (last 3 months)'],
      repaymentInformation: 'Choose a repayment date that suits your salary cycle. Part-prepayment allowed anytime.',
      approvalSpeed: ApprovalSpeed.quick,
      isFeatured: true,
    ),
    LoanOffer(
      id: 'suryan-personal',
      lenderId: 'suryan',
      lenderName: 'Suryan Capital',
      lenderIcon: Icons.savings_outlined,
      lenderColor: Color(0xFFC79A3D),
      loanType: 'Personal Loan',
      loanAmount: 200000,
      interestRatePercent: 13.5,
      tenureMonths: 24,
      processingFeePercent: 2.0,
      benefits: ['Trusted lender', 'Easy disbursal'],
      eligibilityRequirements: [
        'Age between 21 and 55 years',
        'Minimum monthly income of ₹18,000',
        'Stable employment for 1+ year',
      ],
      requiredDocuments: ['PAN card', 'Address proof', 'Salary slips (last 2 months)'],
      repaymentInformation: 'Standard monthly EMI via auto-debit. Foreclosure allowed after 12 months.',
      approvalSpeed: ApprovalSpeed.standard,
      isFeatured: true,
    ),
    LoanOffer(
      id: 'bluepeak-personal-small',
      lenderId: 'bluepeak',
      lenderName: 'Bluepeak Bank',
      lenderIcon: Icons.account_balance_outlined,
      lenderColor: Color(0xFF102A43),
      loanType: 'Personal Loan',
      loanAmount: 100000,
      interestRatePercent: 11.8,
      tenureMonths: 12,
      processingFeePercent: 1.0,
      benefits: ['Instant approval', 'Low processing fee'],
      eligibilityRequirements: [
        'Age between 23 and 60 years',
        'Minimum monthly income of ₹18,000',
      ],
      requiredDocuments: ['PAN card', 'Bank statements (last 3 months)'],
      repaymentInformation: 'Short-tenure loan with fixed monthly EMI. No prepayment penalty.',
      approvalSpeed: ApprovalSpeed.instant,
    ),
    LoanOffer(
      id: 'greenline-business',
      lenderId: 'greenline',
      lenderName: 'Greenline Finance',
      lenderIcon: Icons.storefront_outlined,
      lenderColor: Color(0xFF3F7D4F),
      loanType: 'Business Loan',
      loanAmount: 500000,
      interestRatePercent: 14.0,
      tenureMonths: 36,
      processingFeePercent: 2.5,
      benefits: ['GST-linked underwriting', 'Flexible repayment'],
      eligibilityRequirements: [
        'Business registered for 1+ year',
        'Minimum annual turnover of ₹6,00,000',
        'GST filings up to date',
      ],
      requiredDocuments: ['PAN card', 'GST registration certificate', 'Business bank statements (last 6 months)'],
      repaymentInformation: 'Monthly EMI aligned with your business cash flow. Seasonal repayment options available.',
      approvalSpeed: ApprovalSpeed.quick,
    ),
    LoanOffer(
      id: 'novafin-business',
      lenderId: 'novafin',
      lenderName: 'NovaFin',
      lenderIcon: Icons.account_balance,
      lenderColor: Color(0xFF2E5FA3),
      loanType: 'Business Loan',
      loanAmount: 300000,
      interestRatePercent: 15.5,
      tenureMonths: 18,
      processingFeePercent: 2.0,
      benefits: ['Minimal documentation', 'Quick disbursal'],
      eligibilityRequirements: [
        'Business registered for 6+ months',
        'Minimum annual turnover of ₹3,00,000',
      ],
      requiredDocuments: ['PAN card', 'Business registration proof', 'Bank statements (last 6 months)'],
      repaymentInformation: 'Standard monthly EMI via auto-debit. Foreclosure allowed after 6 months.',
      approvalSpeed: ApprovalSpeed.standard,
    ),
  ];
}
