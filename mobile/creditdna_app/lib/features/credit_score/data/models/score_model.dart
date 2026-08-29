import 'package:flutter/material.dart';

class MonthlyScoreModel {
  final String month; // short label, e.g. "Jun"
  final int score;

  const MonthlyScoreModel({required this.month, required this.score});
}

/// A factor doesn't necessarily mean "higher is always simply better" the
/// same way across factors (e.g. a risk-indicator score reads differently
/// from an income-stability score) — [colorType] is therefore set
/// explicitly per factor rather than auto-derived from [score].
enum FactorColorType { positive, moderate, attention }

enum FactorDataAvailability { available, notConnected }

class FinancialFactorModel {
  final String id;
  final String title;
  final String description;
  final int score;
  final int maxScore;

  /// Short human label for what the score means, e.g. "Strong", "Good",
  /// "Needs attention" — shown on the detail screen.
  final String scoreMeaning;
  final FactorColorType colorType;
  final FactorDataAvailability dataAvailability;
  final IconData icon;

  /// Route to send the user to when this factor's data isn't connected yet.
  final String connectRoute;

  /// Mini trend for the factor detail screen.
  final List<double> trendPoints;
  final List<String> keyObservations;
  final String suggestion;

  const FinancialFactorModel({
    required this.id,
    required this.title,
    required this.description,
    required this.score,
    required this.maxScore,
    required this.scoreMeaning,
    required this.colorType,
    required this.dataAvailability,
    required this.icon,
    required this.connectRoute,
    this.trendPoints = const [],
    this.keyObservations = const [],
    this.suggestion = '',
  });

  double get progress => maxScore == 0 ? 0 : (score / maxScore).clamp(0.0, 1.0);
}

class RecommendationModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String route;

  const RecommendationModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
  });
}

class FinancialReportModel {
  final int creditDnaScore;
  final int maxScore;
  final String scoreStatus;
  final int scoreChange;

  /// "Ahead of X% of CredNest users" — clearly temporary/demo until a real
  /// aggregate-comparison backend exists (see [ScoringRepository]).
  final int percentile;

  final DateTime updatedAt;
  final List<MonthlyScoreModel> trend;
  final List<FinancialFactorModel> financialFactors;
  final List<RecommendationModel> recommendations;

  /// When false, the score/trend sections show a "connect your bank"
  /// empty state instead of fabricating numbers.
  final bool hasBankData;

  const FinancialReportModel({
    required this.creditDnaScore,
    required this.maxScore,
    required this.scoreStatus,
    required this.scoreChange,
    required this.percentile,
    required this.updatedAt,
    required this.trend,
    required this.financialFactors,
    required this.recommendations,
    required this.hasBankData,
  });
}
