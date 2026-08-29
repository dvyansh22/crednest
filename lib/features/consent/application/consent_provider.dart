import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/consent_model.dart';
import '../data/repositories/consent_repository.dart';

final consentRepositoryProvider = Provider<ConsentRepository>((ref) => ConsentRepository());

enum ConsentLoadStatus { loading, loaded, error }

class ConsentState {
  final ConsentLoadStatus status;
  final List<ConsentModel> consents;
  final String? errorMessage;

  const ConsentState({required this.status, this.consents = const [], this.errorMessage});

  const ConsentState.loading() : this(status: ConsentLoadStatus.loading);

  int get activeCount => consents.where((c) => c.status == ConsentStatus.active).length;

  int get totalCount => consents.length;

  /// 0..1 — never hardcoded, always derived from the current consent list.
  double get activePercent => totalCount == 0 ? 0 : activeCount / totalCount;

  String get overallLabel {
    if (totalCount == 0) return 'No data yet';
    if (activePercent >= 0.8) return 'Good';
    if (activePercent >= 0.5) return 'Fair';
    return 'Needs Attention';
  }
}

class ConsentNotifier extends StateNotifier<ConsentState> {
  ConsentNotifier(this._repository) : super(const ConsentState.loading());

  final ConsentRepository _repository;

  Future<void> loadConsents() async {
    state = const ConsentState.loading();
    try {
      final consents = await _repository.getConsents();
      state = ConsentState(status: ConsentLoadStatus.loaded, consents: consents);
    } catch (_) {
      state = const ConsentState(
        status: ConsentLoadStatus.error,
        errorMessage: 'Unable to load your consent information.',
      );
    }
  }

  Future<void> revokeConsent(String id) async {
    await _repository.revokeConsent(id);
    state = ConsentState(
      status: ConsentLoadStatus.loaded,
      consents: [
        for (final c in state.consents)
          if (c.id == id) c.copyWith(status: ConsentStatus.revoked) else c,
      ],
    );
  }

  Future<void> renewConsent(String id) async {
    final newExpiry = await _repository.renewConsent(id);
    state = ConsentState(
      status: ConsentLoadStatus.loaded,
      consents: [
        for (final c in state.consents)
          if (c.id == id) c.copyWith(status: ConsentStatus.active, expiryDate: newExpiry) else c,
      ],
    );
  }
}

final consentProvider = StateNotifierProvider<ConsentNotifier, ConsentState>((ref) {
  return ConsentNotifier(ref.watch(consentRepositoryProvider));
});
