enum LoanApplicationStatus { submitted, underReview, approved, disbursed, rejected }

extension LoanApplicationStatusX on LoanApplicationStatus {
  String get label {
    switch (this) {
      case LoanApplicationStatus.submitted:
        return 'Application Submitted';
      case LoanApplicationStatus.underReview:
        return 'Under Review';
      case LoanApplicationStatus.approved:
        return 'Approved';
      case LoanApplicationStatus.disbursed:
        return 'Disbursed';
      case LoanApplicationStatus.rejected:
        return 'Application Not Approved';
    }
  }
}

class LoanApplication {
  final String applicationId;
  final String userId;
  final String offerId;
  final double requestedAmount;
  final LoanApplicationStatus status;
  final DateTime submittedAt;
  final double? approvedAmount;
  final double? finalInterestRate;
  final double? finalEmi;
  final int? finalTenureMonths;
  final DateTime? disbursedAt;
  final String? maskedAccountReference;

  const LoanApplication({
    required this.applicationId,
    required this.userId,
    required this.offerId,
    required this.requestedAmount,
    required this.status,
    required this.submittedAt,
    this.approvedAmount,
    this.finalInterestRate,
    this.finalEmi,
    this.finalTenureMonths,
    this.disbursedAt,
    this.maskedAccountReference,
  });

  LoanApplication copyWith({
    LoanApplicationStatus? status,
    double? approvedAmount,
    double? finalInterestRate,
    double? finalEmi,
    int? finalTenureMonths,
    DateTime? disbursedAt,
    String? maskedAccountReference,
  }) {
    return LoanApplication(
      applicationId: applicationId,
      userId: userId,
      offerId: offerId,
      requestedAmount: requestedAmount,
      status: status ?? this.status,
      submittedAt: submittedAt,
      approvedAmount: approvedAmount ?? this.approvedAmount,
      finalInterestRate: finalInterestRate ?? this.finalInterestRate,
      finalEmi: finalEmi ?? this.finalEmi,
      finalTenureMonths: finalTenureMonths ?? this.finalTenureMonths,
      disbursedAt: disbursedAt ?? this.disbursedAt,
      maskedAccountReference: maskedAccountReference ?? this.maskedAccountReference,
    );
  }
}
