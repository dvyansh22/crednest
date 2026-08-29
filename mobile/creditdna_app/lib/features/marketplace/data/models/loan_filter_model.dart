import 'loan_offer_model.dart';

class LoanFilter {
  final double? minimumAmount;
  final double? maximumAmount;
  final double? maximumInterestRate;
  final int? tenureMonths;
  final String? loanType;
  final ApprovalSpeed? approvalSpeed;

  const LoanFilter({
    this.minimumAmount,
    this.maximumAmount,
    this.maximumInterestRate,
    this.tenureMonths,
    this.loanType,
    this.approvalSpeed,
  });

  bool get isEmpty =>
      minimumAmount == null &&
      maximumAmount == null &&
      maximumInterestRate == null &&
      tenureMonths == null &&
      loanType == null &&
      approvalSpeed == null;

  LoanFilter copyWith({
    double? minimumAmount,
    double? maximumAmount,
    double? maximumInterestRate,
    int? tenureMonths,
    String? loanType,
    ApprovalSpeed? approvalSpeed,
    bool clearMinimumAmount = false,
    bool clearMaximumAmount = false,
    bool clearMaximumInterestRate = false,
    bool clearTenureMonths = false,
    bool clearLoanType = false,
    bool clearApprovalSpeed = false,
  }) {
    return LoanFilter(
      minimumAmount: clearMinimumAmount ? null : (minimumAmount ?? this.minimumAmount),
      maximumAmount: clearMaximumAmount ? null : (maximumAmount ?? this.maximumAmount),
      maximumInterestRate: clearMaximumInterestRate ? null : (maximumInterestRate ?? this.maximumInterestRate),
      tenureMonths: clearTenureMonths ? null : (tenureMonths ?? this.tenureMonths),
      loanType: clearLoanType ? null : (loanType ?? this.loanType),
      approvalSpeed: clearApprovalSpeed ? null : (approvalSpeed ?? this.approvalSpeed),
    );
  }

  bool matches(LoanOffer offer) {
    if (minimumAmount != null && offer.loanAmount < minimumAmount!) return false;
    if (maximumAmount != null && offer.loanAmount > maximumAmount!) return false;
    if (maximumInterestRate != null && offer.interestRatePercent > maximumInterestRate!) return false;
    if (tenureMonths != null && offer.tenureMonths != tenureMonths) return false;
    if (loanType != null && offer.loanType != loanType) return false;
    if (approvalSpeed != null && offer.approvalSpeed != approvalSpeed) return false;
    return true;
  }
}
