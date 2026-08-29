import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../dashboard/application/dashboard_provider.dart';
import '../../profile/data/models/user_profile_model.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../data/models/loan_application_model.dart';
import '../data/models/loan_filter_model.dart';
import '../data/models/loan_offer_model.dart';
import '../data/repositories/marketplace_repository.dart';

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) => MarketplaceRepository());

enum LoanOffersStatus { loading, loaded, error }

const int kMaxCompareSelection = 3;

class LoanMarketplaceState {
  final LoanOffersStatus status;
  final List<LoanOffer> offers;
  final String searchQuery;
  final LoanFilter filter;
  final Set<String> compareSelection;

  /// Toggled by the "Personalized offers for you" banner — narrows the list
  /// to curated/featured offers as a stand-in for real personalization
  /// until a backend recommendation signal exists.
  final bool personalizedOnly;
  final String? errorMessage;

  const LoanMarketplaceState({
    this.status = LoanOffersStatus.loading,
    this.offers = const [],
    this.searchQuery = '',
    this.filter = const LoanFilter(),
    this.compareSelection = const {},
    this.personalizedOnly = false,
    this.errorMessage,
  });

  List<LoanOffer> get filteredOffers {
    final query = searchQuery.trim().toLowerCase();
    return offers.where((offer) {
      if (personalizedOnly && !offer.isFeatured) return false;
      if (!filter.matches(offer)) return false;
      if (query.isEmpty) return true;
      return offer.lenderName.toLowerCase().contains(query) || offer.loanType.toLowerCase().contains(query);
    }).toList();
  }

  List<LoanOffer> get compareOffers => offers.where((o) => compareSelection.contains(o.id)).toList();

  LoanMarketplaceState copyWith({
    LoanOffersStatus? status,
    List<LoanOffer>? offers,
    String? searchQuery,
    LoanFilter? filter,
    Set<String>? compareSelection,
    bool? personalizedOnly,
    String? errorMessage,
  }) {
    return LoanMarketplaceState(
      status: status ?? this.status,
      offers: offers ?? this.offers,
      searchQuery: searchQuery ?? this.searchQuery,
      filter: filter ?? this.filter,
      compareSelection: compareSelection ?? this.compareSelection,
      personalizedOnly: personalizedOnly ?? this.personalizedOnly,
      errorMessage: errorMessage,
    );
  }
}

class LoanMarketplaceNotifier extends StateNotifier<LoanMarketplaceState> {
  LoanMarketplaceNotifier(this._repository) : super(const LoanMarketplaceState());

  final MarketplaceRepository _repository;

  Future<void> loadOffers() async {
    state = state.copyWith(status: LoanOffersStatus.loading);
    try {
      final offers = await _repository.getLoanOffers();
      state = state.copyWith(status: LoanOffersStatus.loaded, offers: offers);
    } catch (_) {
      state = state.copyWith(status: LoanOffersStatus.error, errorMessage: 'Unable to load loan offers.');
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void applyFilter(LoanFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void resetFilter() {
    state = state.copyWith(filter: const LoanFilter());
  }

  void togglePersonalizedOnly() {
    state = state.copyWith(personalizedOnly: !state.personalizedOnly);
  }

  /// Returns false (without changing selection) if the 3-offer cap would be
  /// exceeded — the UI surfaces that as a message rather than silently
  /// failing.
  bool toggleCompareSelection(String offerId) {
    final current = Set<String>.from(state.compareSelection);
    if (current.contains(offerId)) {
      current.remove(offerId);
      state = state.copyWith(compareSelection: current);
      return true;
    }
    if (current.length >= kMaxCompareSelection) return false;
    current.add(offerId);
    state = state.copyWith(compareSelection: current);
    return true;
  }

  void removeFromCompare(String offerId) {
    final current = Set<String>.from(state.compareSelection)..remove(offerId);
    state = state.copyWith(compareSelection: current);
  }

  void clearCompareSelection() {
    state = state.copyWith(compareSelection: const {});
  }
}

final loanMarketplaceProvider = StateNotifierProvider<LoanMarketplaceNotifier, LoanMarketplaceState>((ref) {
  return LoanMarketplaceNotifier(ref.watch(marketplaceRepositoryProvider));
});

enum LoanApplicationSubmitStatus { idle, submitting, success, error }

class LoanApplicationFlowState {
  final LoanOffer? selectedOffer;
  final double? requestedAmount;
  final LoanApplicationSubmitStatus submitStatus;
  final LoanApplication? application;
  final String? errorMessage;

  const LoanApplicationFlowState({
    this.selectedOffer,
    this.requestedAmount,
    this.submitStatus = LoanApplicationSubmitStatus.idle,
    this.application,
    this.errorMessage,
  });

  LoanApplicationFlowState copyWith({
    LoanOffer? selectedOffer,
    double? requestedAmount,
    LoanApplicationSubmitStatus? submitStatus,
    LoanApplication? application,
    String? errorMessage,
  }) {
    return LoanApplicationFlowState(
      selectedOffer: selectedOffer ?? this.selectedOffer,
      requestedAmount: requestedAmount ?? this.requestedAmount,
      submitStatus: submitStatus ?? this.submitStatus,
      application: application ?? this.application,
      errorMessage: errorMessage,
    );
  }
}

/// Carries state across the multi-screen apply flow (Review -> Consent ->
/// Submit -> Submitted -> Status), the same way [AssessmentNotifier] carries
/// state across the assessment's question screens.
class LoanApplicationNotifier extends StateNotifier<LoanApplicationFlowState> {
  LoanApplicationNotifier(this._repository, this._ref) : super(const LoanApplicationFlowState());

  final MarketplaceRepository _repository;
  final Ref _ref;

  void startApplication(LoanOffer offer) {
    state = LoanApplicationFlowState(selectedOffer: offer, requestedAmount: offer.loanAmount);
  }

  /// Consent categories relevant to this application — GST only for
  /// MSME/business profiles, matching how the Financial Report already
  /// treats GST as user-type-dependent.
  List<String> relevantConsentIds(UserType? userType) {
    return [
      'financial-data',
      'identity-verification',
      if (userType == UserType.msme) 'gst-data',
      'psychometric-assessment',
    ];
  }

  Future<bool> submit() async {
    if (state.submitStatus == LoanApplicationSubmitStatus.submitting) return false;
    final offer = state.selectedOffer;
    if (offer == null) return false;

    state = state.copyWith(submitStatus: LoanApplicationSubmitStatus.submitting);
    try {
      final userId = _ref.read(authProvider).user?.id ?? '';
      final userType = _ref.read(userProfileProvider).profile?.userType;
      final creditDna = _ref.read(dashboardProvider).data?.creditDna;

      final application = await _repository.submitLoanApplication(
        userId: userId,
        offerId: offer.id,
        requestedAmount: state.requestedAmount ?? offer.loanAmount,
        creditDnaScore: (creditDna?.isAvailable ?? false) ? creditDna!.score : null,
        consentIds: relevantConsentIds(userType),
      );

      state = state.copyWith(submitStatus: LoanApplicationSubmitStatus.success, application: application);
      return true;
    } catch (_) {
      state = state.copyWith(
        submitStatus: LoanApplicationSubmitStatus.error,
        errorMessage: 'Something went wrong while submitting your application. Please try again.',
      );
      return false;
    }
  }

  Future<void> refreshStatus() async {
    final application = state.application;
    if (application == null) return;
    final updated = await _repository.getApplicationStatus(application.applicationId);
    if (updated != null) state = state.copyWith(application: updated);
  }
}

final loanApplicationProvider = StateNotifierProvider<LoanApplicationNotifier, LoanApplicationFlowState>((ref) {
  return LoanApplicationNotifier(ref.watch(marketplaceRepositoryProvider), ref);
});
