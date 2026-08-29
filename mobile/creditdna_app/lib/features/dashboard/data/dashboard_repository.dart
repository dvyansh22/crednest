import 'package:flutter/material.dart';

import '../../profile/data/models/user_profile_model.dart';
import 'models/dashboard_models.dart';

/// Flip to `false` locally to preview the "profile is taking shape" state —
/// once a real backend is wired up, [CreditDnaScoreData.isAvailable] will
/// be driven by the API response instead of this constant.
const bool _kDemoScoreAvailable = true;

/// Supplies dashboard content. No backend exists yet, so this returns demo
/// data shaped exactly like the eventual API response — swap the body of
/// [getDashboardData] for real calls (e.g. GET /dashboard/summary,
/// GET /dashboard/income-snapshot) without touching any caller.
class DashboardRepository {
  Future<DashboardData> getDashboardData({required UserType userType}) async {
    return DashboardData(
      creditDna: _buildCreditDna(),
      nextAction: _buildNextAction(),
      connectedData: _buildConnectedData(),
      incomeSnapshot: _buildIncomeSnapshot(userType),
      opportunities: const [], // no backend offers yet — UI shows an honest empty state
    );
  }

  CreditDnaScoreData _buildCreditDna() {
    if (!_kDemoScoreAvailable) {
      return const CreditDnaScoreData(
        isAvailable: false,
        score: 0,
        maxScore: 850,
        status: CreditDnaStatus.building,
        insightText: 'Connect your financial data to unlock a more complete financial profile.',
        profileConfidence: 0.45,
      );
    }
    return const CreditDnaScoreData(
      isAvailable: true,
      score: 742,
      maxScore: 850,
      status: CreditDnaStatus.good,
      insightText: 'Your income consistency is strengthening your profile.',
    );
  }

  NextActionData _buildNextAction() {
    return const NextActionData(
      title: 'Connect your bank account',
      description: 'Unlock deeper insights into your income\nand financial patterns.',
      actionLabel: 'Connect now',
      actionType: NextActionType.connectBank,
      icon: Icons.track_changes_outlined,
    );
  }

  List<ConnectedDataItem> _buildConnectedData() {
    return const [
      ConnectedDataItem(
        title: 'Bank account',
        icon: Icons.account_balance_outlined,
        status: ConnectionStatus.connected,
        route: '/connect-bank',
      ),
      ConnectedDataItem(
        title: 'Identity / KYC',
        icon: Icons.badge_outlined,
        status: ConnectionStatus.verified,
        route: '/kyc-status',
      ),
      ConnectedDataItem(
        title: 'GST data',
        icon: Icons.description_outlined,
        status: ConnectionStatus.notConnected,
        route: '/connect-gst',
      ),
    ];
  }

  IncomeSnapshotData _buildIncomeSnapshot(UserType userType) {
    switch (userType) {
      case UserType.gigWorker:
        return const IncomeSnapshotData(
          label: 'Estimated monthly earnings',
          amount: 34200,
          growthPercent: 8,
          trendPoints: [21000, 24500, 23000, 27500, 26000, 30500, 29000, 32000, 31000, 34200],
          stabilityLabel: 'Earnings consistency',
          stabilityStatus: 'Consistent',
          extraInfo: '3 income sources detected',
        );
      case UserType.msme:
        return const IncomeSnapshotData(
          label: 'Estimated monthly cash flow',
          amount: 186500,
          growthPercent: 9,
          trendPoints: [142000, 138500, 151000, 149000, 160500, 158000, 171000, 176500, 180000, 186500],
          stabilityLabel: 'Cash flow stability',
          stabilityStatus: 'Stable',
          extraInfo: 'Based on GST-linked revenue trend',
        );
      case UserType.individual:
        return const IncomeSnapshotData(
          label: 'Estimated monthly income',
          amount: 42500,
          growthPercent: 12,
          trendPoints: [32000, 30500, 33000, 35500, 37000, 36500, 39000, 40000, 41500, 42500],
          stabilityLabel: 'Income stability',
          stabilityStatus: 'Consistent',
        );
    }
  }
}
