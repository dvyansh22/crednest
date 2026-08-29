import 'package:flutter/material.dart';

enum ConsentStatus { active, inactive, expired, revoked }

extension ConsentStatusX on ConsentStatus {
  String get label {
    switch (this) {
      case ConsentStatus.active:
        return 'Active';
      case ConsentStatus.inactive:
        return 'Inactive';
      case ConsentStatus.expired:
        return 'Expired';
      case ConsentStatus.revoked:
        return 'Revoked';
    }
  }
}

/// One data-sharing consent (financial data, KYC, GST, etc).
///
/// [expiryDate] is the single source of truth for expiry — [daysUntilExpiry]
/// is always derived from it rather than stored separately, so it can never
/// drift out of sync with the date.
class ConsentModel {
  final String id;
  final String title;
  final String purpose;
  final ConsentStatus status;
  final DateTime? expiryDate;
  final IconData icon;
  final Color accentColor;

  /// Route to send the user to when they act on this consent (provide,
  /// renew) — reuses the existing screen for that data category rather than
  /// inventing a separate consent-collection flow.
  final String actionRoute;

  final String whyWeNeedThis;
  final List<String> dataRequested;
  final List<String> dataNeverAccessed;

  const ConsentModel({
    required this.id,
    required this.title,
    required this.purpose,
    required this.status,
    required this.icon,
    required this.accentColor,
    required this.actionRoute,
    required this.whyWeNeedThis,
    required this.dataRequested,
    required this.dataNeverAccessed,
    this.expiryDate,
  });

  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    final diff = expiryDate!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  ConsentModel copyWith({ConsentStatus? status, DateTime? expiryDate}) {
    return ConsentModel(
      id: id,
      title: title,
      purpose: purpose,
      status: status ?? this.status,
      expiryDate: expiryDate ?? this.expiryDate,
      icon: icon,
      accentColor: accentColor,
      actionRoute: actionRoute,
      whyWeNeedThis: whyWeNeedThis,
      dataRequested: dataRequested,
      dataNeverAccessed: dataNeverAccessed,
    );
  }
}
