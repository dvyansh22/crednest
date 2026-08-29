import 'package:flutter/material.dart';

enum ApprovalSpeed { instant, quick, standard }

extension ApprovalSpeedX on ApprovalSpeed {
  String get label {
    switch (this) {
      case ApprovalSpeed.instant:
        return 'Instant approval';
      case ApprovalSpeed.quick:
        return 'Quick approval';
      case ApprovalSpeed.standard:
        return 'Standard approval';
    }
  }

  IconData get icon {
    switch (this) {
      case ApprovalSpeed.instant:
        return Icons.bolt;
      case ApprovalSpeed.quick:
        return Icons.check_circle_outline;
      case ApprovalSpeed.standard:
        return Icons.schedule;
    }
  }
}

/// A lender's offer. EMI, processing-fee amount, and total repayment are
/// derived getters — never stored — so they can never drift out of sync
/// with [loanAmount] / [interestRatePercent] / [tenureMonths].
class LoanOffer {
  final String id;
  final String lenderId;
  final String lenderName;
  final IconData lenderIcon;
  final Color lenderColor;
  final String loanType;
  final double loanAmount;
  final double interestRatePercent;
  final int tenureMonths;
  final double processingFeePercent;
  final List<String> benefits;
  final List<String> eligibilityRequirements;
  final List<String> requiredDocuments;
  final String repaymentInformation;
  final bool isFeatured;
  final ApprovalSpeed approvalSpeed;

  const LoanOffer({
    required this.id,
    required this.lenderId,
    required this.lenderName,
    required this.lenderIcon,
    required this.lenderColor,
    required this.loanType,
    required this.loanAmount,
    required this.interestRatePercent,
    required this.tenureMonths,
    required this.processingFeePercent,
    required this.benefits,
    required this.eligibilityRequirements,
    required this.requiredDocuments,
    required this.repaymentInformation,
    required this.approvalSpeed,
    this.isFeatured = false,
  });

  /// Standard reducing-balance EMI formula — computed, not fabricated.
  double get emi {
    final monthlyRate = interestRatePercent / 12 / 100;
    if (monthlyRate == 0) return loanAmount / tenureMonths;
    final factor = _pow(1 + monthlyRate, tenureMonths);
    return loanAmount * monthlyRate * factor / (factor - 1);
  }

  double get processingFeeAmount => loanAmount * processingFeePercent / 100;

  double get totalEstimatedRepayment => emi * tenureMonths;

  static double _pow(double base, int exponent) {
    double result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}
