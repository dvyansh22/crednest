import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../dashboard/presentation/widgets/dashboard_bottom_nav.dart';
import '../application/marketplace_provider.dart';
import '../data/models/loan_offer_model.dart';
import 'widgets/loan_filter_sheet.dart';
import 'widgets/loan_offer_card.dart';

class LoanMarketplaceScreen extends ConsumerStatefulWidget {
  const LoanMarketplaceScreen({super.key});

  @override
  ConsumerState<LoanMarketplaceScreen> createState() => _LoanMarketplaceScreenState();
}

class _LoanMarketplaceScreenState extends ConsumerState<LoanMarketplaceScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(loanMarketplaceProvider.notifier).loadOffers());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFilterSheet(List<LoanOffer> allOffers) {
    final notifier = ref.read(loanMarketplaceProvider.notifier);
    final types = allOffers.map((o) => o.loanType).toSet().toList();
    showLoanFilterSheet(
      context: context,
      currentFilter: ref.read(loanMarketplaceProvider).filter,
      availableLoanTypes: types,
      onApply: notifier.applyFilter,
      onReset: notifier.resetFilter,
    );
  }

  void _openOfferDetail(LoanOffer offer) {
    context.push('/offers/${offer.id}', extra: offer);
  }

  void _handleCompareToggle(String offerId) {
    final applied = ref.read(loanMarketplaceProvider.notifier).toggleCompareSelection(offerId);
    if (!applied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can compare up to $kMaxCompareSelection offers at a time.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loanMarketplaceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const DashboardBottomNav(currentIndex: 3),
      body: SafeArea(
        child: Column(
          children: [
            _Header(onHelp: () => _showHelpSheet(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: _SearchBar(
                controller: _searchController,
                onChanged: (value) => ref.read(loanMarketplaceProvider.notifier).setSearchQuery(value),
                onFilterTap: () => _openFilterSheet(state.offers),
              ),
            ),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('About the Loan Marketplace', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
              SizedBox(height: 10),
              Text(
                'Browse offers from partner lenders, compare up to 3 side by side, and apply directly. '
                'Rates and eligibility shown here are indicative and confirmed by the lender during review.',
                style: TextStyle(fontSize: 13.5, color: AppColors.subGrey, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(LoanMarketplaceState state) {
    switch (state.status) {
      case LoanOffersStatus.loading:
        return const _MarketplaceSkeleton();
      case LoanOffersStatus.error:
        return _MarketplaceError(
          message: state.errorMessage ?? 'Unable to load loan offers.',
          onRetry: () => ref.read(loanMarketplaceProvider.notifier).loadOffers(),
        );
      case LoanOffersStatus.loaded:
        final offers = state.filteredOffers;
        return RefreshIndicator(
          color: AppColors.blue,
          onRefresh: () => ref.read(loanMarketplaceProvider.notifier).loadOffers(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PersonalizedBanner(
                  isActive: state.personalizedOnly,
                  onTap: () => ref.read(loanMarketplaceProvider.notifier).togglePersonalizedOnly(),
                ),
                const SizedBox(height: 22),
                if (offers.isEmpty)
                  _EmptyOffersState(
                    onClearFilters: () {
                      _searchController.clear();
                      final notifier = ref.read(loanMarketplaceProvider.notifier);
                      notifier.setSearchQuery('');
                      notifier.resetFilter();
                    },
                  )
                else ...[
                  Row(
                    children: [
                      const Text('Top Picks for You', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      const Spacer(),
                      Text('${offers.length} offers', style: const TextStyle(fontSize: 12.5, color: AppColors.subGrey)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (final offer in offers) ...[
                    LoanOfferCard(
                      offer: offer,
                      onViewDetails: () => _openOfferDetail(offer),
                      isSelectedForCompare: state.compareSelection.contains(offer.id),
                      onCompareChanged: (_) => _handleCompareToggle(offer.id),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
                const SizedBox(height: 8),
                _CompareBanner(selectionCount: state.compareSelection.length),
              ],
            ),
          ),
        );
    }
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onHelp;
  const _Header({required this.onHelp});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
            icon: const Icon(Icons.arrow_back, color: AppColors.navy),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Loan Marketplace', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 3),
                  const Text('Explore loan offers that fit your needs', style: TextStyle(fontSize: 12.5, color: AppColors.subGrey)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: IconButton(onPressed: onHelp, icon: const Icon(Icons.help_outline, color: AppColors.navy)),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;

  const _SearchBar({required this.controller, required this.onChanged, required this.onFilterTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: AppColors.subGrey),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14, color: AppColors.navy),
              decoration: const InputDecoration(
                hintText: 'Search lenders or loan types',
                hintStyle: TextStyle(fontSize: 13.5, color: AppColors.subGrey),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          InkWell(
            onTap: onFilterTap,
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.tune, size: 20, color: AppColors.navy),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalizedBanner extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  const _PersonalizedBanner({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.greenTint,
          borderRadius: BorderRadius.circular(16),
          border: isActive ? Border.all(color: AppColors.green, width: 1.4) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.star_outline_rounded, size: 17, color: AppColors.green),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Personalized offers for you', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  SizedBox(height: 2),
                  Text('Based on your profile and CreditDNA score', style: TextStyle(fontSize: 11.5, color: AppColors.subGrey)),
                ],
              ),
            ),
            Icon(isActive ? Icons.check_circle : Icons.chevron_right, size: isActive ? 20 : 22, color: AppColors.green),
          ],
        ),
      ),
    );
  }
}

class _CompareBanner extends StatelessWidget {
  final int selectionCount;
  const _CompareBanner({required this.selectionCount});

  @override
  Widget build(BuildContext context) {
    final canCompare = selectionCount >= 2;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Want to compare offers?', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 3),
                Text(
                  selectionCount == 0
                      ? 'Compare up to 3 offers side by side.'
                      : '$selectionCount of $kMaxCompareSelection selected',
                  style: const TextStyle(fontSize: 12, color: AppColors.subGrey),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: canCompare ? () => context.push('/offers/compare') : null,
            icon: const Icon(Icons.balance, size: 16),
            label: const Text('Compare', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navy,
              disabledForegroundColor: AppColors.subGrey,
              side: BorderSide(color: canCompare ? AppColors.navy : AppColors.cardBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOffersState extends StatelessWidget {
  final VoidCallback onClearFilters;
  const _EmptyOffersState({required this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(color: AppColors.fieldFill, shape: BoxShape.circle),
            child: const Icon(Icons.search_off, color: AppColors.subGrey, size: 26),
          ),
          const SizedBox(height: 16),
          const Text('No loan offers found.', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onClearFilters,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navy,
              side: const BorderSide(color: AppColors.cardBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Clear Filters', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceSkeleton extends StatelessWidget {
  const _MarketplaceSkeleton();

  Widget _block({double height = 190}) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: AppColors.cardBorder.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(children: [_block(height: 70), _block(), _block(), _block()]),
    );
  }
}

class _MarketplaceError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _MarketplaceError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.subGrey, size: 34),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.subGrey, height: 1.4)),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
