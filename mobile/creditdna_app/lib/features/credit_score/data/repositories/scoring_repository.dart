import 'package:flutter/material.dart';

import '../../../profile/data/models/user_profile_model.dart';
import '../models/score_model.dart';

/// Supplies the Financial Report. No backend exists yet — [getFinancialReport]
/// returns demo data shaped like the eventual API response. Swap its body
/// for a real call (GET /financial-report) without touching any caller.
///
/// [percentile] in the returned model is explicitly demo/placeholder data —
/// see the field doc on [FinancialReportModel.percentile].
class ScoringRepository {
  Future<FinancialReportModel> getFinancialReport({
    required UserType userType,
    required bool bankConnected,
    required bool gstConnected,
    required bool assessmentCompleted,
  }) async {
    // TODO(backend): replace with GET /financial-report
    await Future.delayed(const Duration(milliseconds: 500));

    return FinancialReportModel(
      creditDnaScore: 742,
      maxScore: 850,
      scoreStatus: 'Good',
      scoreChange: 18,
      percentile: 68,
      updatedAt: DateTime.now(),
      hasBankData: bankConnected,
      trend: const [
        MonthlyScoreModel(month: 'Jun', score: 696),
        MonthlyScoreModel(month: 'Jul', score: 724),
        MonthlyScoreModel(month: 'Aug', score: 742),
      ],
      financialFactors: _buildFactors(userType: userType, bankConnected: bankConnected, gstConnected: gstConnected),
      recommendations: _buildRecommendations(gstConnected: gstConnected),
    );
  }

  List<FinancialFactorModel> _buildFactors({
    required UserType userType,
    required bool bankConnected,
    required bool gstConnected,
  }) {
    final bankAvailability = bankConnected ? FactorDataAvailability.available : FactorDataAvailability.notConnected;

    // GST only applies meaningfully to MSME/business profiles — individuals
    // and gig workers see an honest "not connected" state rather than a
    // fabricated business filing score.
    final gstApplies = userType == UserType.msme;
    final gstAvailability =
        gstApplies && gstConnected ? FactorDataAvailability.available : FactorDataAvailability.notConnected;

    return [
      FinancialFactorModel(
        id: 'income-stability',
        title: 'Income Stability',
        description: 'Consistency of your income',
        score: 88,
        maxScore: 100,
        scoreMeaning: 'Strong',
        colorType: FactorColorType.positive,
        dataAvailability: bankAvailability,
        icon: Icons.show_chart,
        connectRoute: '/connect-bank',
        trendPoints: const [78, 80, 82, 85, 83, 86, 88],
        keyObservations: const [
          'Your income has remained relatively consistent.',
          'Your average monthly income increased recently.',
          'Some variation was detected during one period.',
        ],
        suggestion: 'Maintaining consistent income records can help strengthen your financial profile.',
      ),
      FinancialFactorModel(
        id: 'cash-flow',
        title: 'Cash Flow',
        description: 'Balance of income and expenses',
        score: 79,
        maxScore: 100,
        scoreMeaning: 'Good',
        colorType: FactorColorType.positive,
        dataAvailability: bankAvailability,
        icon: Icons.account_balance_wallet_outlined,
        connectRoute: '/connect-bank',
        trendPoints: const [70, 74, 72, 76, 75, 78, 79],
        keyObservations: const [
          'Your income has comfortably covered your expenses most months.',
          'Outflows have stayed close to inflows with a healthy buffer.',
        ],
        suggestion: 'Keeping a consistent gap between income and expenses supports a stronger cash flow score.',
      ),
      FinancialFactorModel(
        id: 'spending-behavior',
        title: 'Spending Behavior',
        description: 'How responsibly you spend',
        score: 82,
        maxScore: 100,
        scoreMeaning: 'Good',
        colorType: FactorColorType.positive,
        dataAvailability: bankAvailability,
        icon: Icons.shopping_bag_outlined,
        connectRoute: '/connect-bank',
        trendPoints: const [74, 76, 79, 78, 80, 81, 82],
        keyObservations: const [
          'Discretionary spending has stayed within a steady range.',
          'No unusual spikes were detected in recent months.',
        ],
        suggestion: 'Continuing to plan discretionary spending in advance can help sustain this score.',
      ),
      FinancialFactorModel(
        id: 'income-sources',
        title: 'Income Sources',
        description: 'Diversity of your income',
        score: 76,
        maxScore: 100,
        scoreMeaning: 'Good',
        colorType: FactorColorType.positive,
        dataAvailability: bankAvailability,
        icon: Icons.people_outline,
        connectRoute: '/connect-bank',
        trendPoints: const [60, 63, 68, 70, 72, 74, 76],
        keyObservations: const [
          'Multiple income sources were detected in your connected accounts.',
          'Diversified income can add resilience to your financial profile.',
        ],
        suggestion: 'Keeping additional income sources connected gives a fuller picture of your finances.',
      ),
      FinancialFactorModel(
        id: 'gst-consistency',
        title: 'GST Consistency',
        description: 'Business reporting consistency',
        score: 87,
        maxScore: 100,
        scoreMeaning: 'Strong',
        colorType: FactorColorType.positive,
        dataAvailability: gstAvailability,
        icon: Icons.description_outlined,
        connectRoute: '/connect-gst',
        trendPoints: const [79, 81, 83, 84, 85, 86, 87],
        keyObservations: const [
          'GST filings have been consistent over the recent period.',
          'Reported turnover trends have remained stable.',
        ],
        suggestion: 'Continuing to file on schedule keeps this signal strong.',
      ),
      FinancialFactorModel(
        id: 'financial-risk-indicators',
        title: 'Financial Risk Indicators',
        description: 'Potential areas of concern',
        score: 62,
        maxScore: 100,
        scoreMeaning: 'Needs attention',
        colorType: FactorColorType.attention,
        dataAvailability: bankAvailability,
        icon: Icons.warning_amber_rounded,
        connectRoute: '/connect-bank',
        trendPoints: const [58, 60, 59, 61, 60, 63, 62],
        keyObservations: const [
          'A small number of transactions were flagged for review.',
          'Overall risk exposure remains within a moderate range.',
        ],
        suggestion: 'Reviewing flagged transactions and keeping data sources current can help lower this score over time.',
      ),
    ];
  }

  List<RecommendationModel> _buildRecommendations({required bool gstConnected}) {
    return [
      if (!gstConnected)
        const RecommendationModel(
          id: 'connect-gst',
          title: 'Connect GST Data',
          description: 'Add GST to get a more complete business insight.',
          icon: Icons.account_tree_outlined,
          route: '/connect-gst',
        ),
      const RecommendationModel(
        id: 'keep-bank-consent-active',
        title: 'Keep Bank Consent Active',
        description: 'Ensure uninterrupted access to your financial data.',
        icon: Icons.shield_outlined,
        route: '/consent/financial-data',
      ),
    ];
  }
}
