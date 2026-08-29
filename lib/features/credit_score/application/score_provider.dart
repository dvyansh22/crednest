import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../consent/application/consent_provider.dart';
import '../../consent/data/models/consent_model.dart';
import '../../dashboard/application/dashboard_provider.dart';
import '../../dashboard/data/models/dashboard_models.dart';
import '../../profile/data/models/user_profile_model.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../data/models/score_model.dart';
import '../data/repositories/scoring_repository.dart';

final scoringRepositoryProvider = Provider<ScoringRepository>((ref) => ScoringRepository());

enum FinancialReportStatus { loading, loaded, error }

class FinancialReportState {
  final FinancialReportStatus status;
  final FinancialReportModel? report;
  final String? errorMessage;

  const FinancialReportState({
    this.status = FinancialReportStatus.loading,
    this.report,
    this.errorMessage,
  });
}

/// Orchestrates the Financial Report: pulls connection/assessment signals
/// from the dashboard, consent, and profile providers, then asks the
/// scoring repository to shape a report around them.
class FinancialReportNotifier extends StateNotifier<FinancialReportState> {
  FinancialReportNotifier(this._repository, this._ref) : super(const FinancialReportState());

  final ScoringRepository _repository;
  final Ref _ref;

  Future<void> loadReport() async {
    state = const FinancialReportState(status: FinancialReportStatus.loading);
    try {
      final userType = _ref.read(userProfileProvider).profile?.userType ?? UserType.individual;
      final connectedData = _ref.read(dashboardProvider).data?.connectedData ?? const [];

      bool isConnected(String title) => connectedData.any(
            (item) =>
                item.title == title &&
                (item.status == ConnectionStatus.connected || item.status == ConnectionStatus.verified),
          );

      final bankConnected = isConnected('Bank account');
      final gstConnected = isConnected('GST data');
      final assessmentCompleted = _ref
          .read(consentProvider)
          .consents
          .any((c) => c.id == 'psychometric-assessment' && c.status == ConsentStatus.active);

      final report = await _repository.getFinancialReport(
        userType: userType,
        bankConnected: bankConnected,
        gstConnected: gstConnected,
        assessmentCompleted: assessmentCompleted,
      );
      state = FinancialReportState(status: FinancialReportStatus.loaded, report: report);
    } catch (_) {
      state = const FinancialReportState(
        status: FinancialReportStatus.error,
        errorMessage: 'Unable to load your financial report. Please try again.',
      );
    }
  }
}

final financialReportProvider = StateNotifierProvider<FinancialReportNotifier, FinancialReportState>((ref) {
  return FinancialReportNotifier(ref.watch(scoringRepositoryProvider), ref);
});
