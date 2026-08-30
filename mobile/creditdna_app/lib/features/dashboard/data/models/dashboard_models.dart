import 'package:flutter/material.dart';

enum CreditDnaStatus { excellent, good, building, needsAttention }

extension CreditDnaStatusX on CreditDnaStatus {
  String get label {
    switch (this) {
      case CreditDnaStatus.excellent:
        return 'Excellent';
      case CreditDnaStatus.good:
        return 'Good';
      case CreditDnaStatus.building:
        return 'Building';
      case CreditDnaStatus.needsAttention:
        return 'Needs Attention';
    }
  }
}

/// Drives which CreditDNA card state renders: a real score, or the
/// "profile is taking shape" state while data confidence is still low.
class CreditDnaScoreData {
  final bool isAvailable;
  final int score;
  final int maxScore;
  final CreditDnaStatus status;
  final String insightText;

  /// Only meaningful when [isAvailable] is false — 0..1.
  final double profileConfidence;

  const CreditDnaScoreData({
    required this.isAvailable,
    required this.score,
    required this.maxScore,
    required this.status,
    required this.insightText,
    this.profileConfidence = 0,
  });
}

enum NextActionType { connectBank, verifyIdentity, connectGst, completeAssessment, renewConsent }

class NextActionData {
  final String title;
  final String description;
  final String actionLabel;
  final NextActionType actionType;
  final IconData icon;

  const NextActionData({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.actionType,
    required this.icon,
  });

  /// Route each action type resolves to — kept here so the UI stays a
  /// simple lookup rather than a growing switch statement per screen.
  String get route {
    switch (actionType) {
      case NextActionType.connectBank:
        return '/connect-bank';
      case NextActionType.verifyIdentity:
        return '/kyc';
      case NextActionType.connectGst:
        return '/connect-gst';
      case NextActionType.completeAssessment:
        return '/psychometric-quiz';
      case NextActionType.renewConsent:
        return '/connect-bank';
    }
  }
}

enum ConnectionStatus { connected, verified, notConnected, expired, revoked }

extension ConnectionStatusX on ConnectionStatus {
  String get label {
    switch (this) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.verified:
        return 'Verified';
      case ConnectionStatus.notConnected:
        return 'Not connected';
      case ConnectionStatus.expired:
        return 'Expired';
      case ConnectionStatus.revoked:
        return 'Revoked';
    }
  }
}

class ConnectedDataItem {
  final String title;
  final IconData icon;
  final ConnectionStatus status;
  final String route;

  const ConnectedDataItem({
    required this.title,
    required this.icon,
    required this.status,
    required this.route,
  });
}

class IncomeSnapshotData {
  final String label;
  final double amount;

  /// Null when there's no prior-period data to compare against.
  final double? growthPercent;
  final List<double> trendPoints;
  final String stabilityLabel;
  final String stabilityStatus;

  /// e.g. "3 income sources detected" for gig workers — null when not applicable.
  final String? extraInfo;

  const IncomeSnapshotData({
    required this.label,
    required this.amount,
    required this.trendPoints,
    required this.stabilityLabel,
    required this.stabilityStatus,
    this.growthPercent,
    this.extraInfo,
  });
}

class OpportunityPreview {
  final String title;
  final double maxAmount;
  final double startingRatePercent;
  final String route;

  const OpportunityPreview({
    required this.title,
    required this.maxAmount,
    required this.startingRatePercent,
    required this.route,
  });
}

class DashboardData {
  final CreditDnaScoreData creditDna;
  final NextActionData nextAction;
  final List<ConnectedDataItem> connectedData;
  final IncomeSnapshotData incomeSnapshot;
  final List<OpportunityPreview> opportunities;

  const DashboardData({
    required this.creditDna,
    required this.nextAction,
    required this.connectedData,
    required this.incomeSnapshot,
    required this.opportunities,
  });
}
