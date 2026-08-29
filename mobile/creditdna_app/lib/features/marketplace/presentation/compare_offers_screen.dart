import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../application/marketplace_provider.dart';
import '../data/models/loan_offer_model.dart';
import 'widgets/compare_offer_card.dart';

const double _kLabelColumnWidth = 118;
const double _kOfferColumnWidth = 152;

class CompareOffersScreen extends ConsumerWidget {
  const CompareOffersScreen({super.key});

  String _formatAmount(double amount) {
    final rounded = amount.round().toString();
    final buffer = StringBuffer();
    final digits = rounded.split('').reversed.toList();
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || (i > 3 && (i - 3) % 2 == 0)) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '₹${buffer.toString().split('').reversed.join()}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(loanMarketplaceProvider).compareOffers;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 4),
              child: Row(
                children: [
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back, color: AppColors.navy)),
                  const Expanded(
                    child: Text(
                      'Compare Offers',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: offers.length < 2
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Select at least 2 offers from the Loan Marketplace to compare them here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.subGrey),
                        ),
                      ),
                    )
                  : _CompareTable(
                      offers: offers,
                      formatAmount: _formatAmount,
                      onRemove: (id) => ref.read(loanMarketplaceProvider.notifier).removeFromCompare(id),
                      onView: (offer) => context.push('/offers/${offer.id}', extra: offer),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareTable extends StatelessWidget {
  final List<LoanOffer> offers;
  final String Function(double) formatAmount;
  final ValueChanged<String> onRemove;
  final ValueChanged<LoanOffer> onView;

  const _CompareTable({required this.offers, required this.formatAmount, required this.onRemove, required this.onView});

  @override
  Widget build(BuildContext context) {
    final lowestRate = offers.map((o) => o.interestRatePercent).reduce((a, b) => a < b ? a : b);
    final lowestEmi = offers.map((o) => o.emi).reduce((a, b) => a < b ? a : b);
    final fastestSpeedIndex = offers.map((o) => o.approvalSpeed.index).reduce((a, b) => a < b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: {
            0: const FixedColumnWidth(_kLabelColumnWidth),
            for (int i = 0; i < offers.length; i++) i + 1: const FixedColumnWidth(_kOfferColumnWidth),
          },
          children: [
            TableRow(
              children: [
                const SizedBox(),
                for (final offer in offers)
                  Padding(
                    padding: const EdgeInsets.only(left: 10, bottom: 14),
                    child: CompareOfferCard(offer: offer, onRemove: () => onRemove(offer.id), onView: () => onView(offer)),
                  ),
              ],
            ),
            _row('Loan Amount', offers.map((o) => formatAmount(o.loanAmount)).toList()),
            _row(
              'Interest Rate',
              offers.map((o) => '${o.interestRatePercent.toStringAsFixed(1)}% p.a.').toList(),
              highlight: offers.map((o) => o.interestRatePercent == lowestRate).toList(),
              highlightLabel: 'Lowest rate',
            ),
            _row('Tenure', offers.map((o) => '${o.tenureMonths} Months').toList()),
            _row(
              'EMI',
              offers.map((o) => formatAmount(o.emi)).toList(),
              highlight: offers.map((o) => o.emi == lowestEmi).toList(),
              highlightLabel: 'Lowest EMI',
            ),
            _row('Processing Fee', offers.map((o) => '${o.processingFeePercent}%').toList()),
            _row(
              'Approval Speed',
              offers.map((o) => o.approvalSpeed.label.replaceAll(' approval', '')).toList(),
              highlight: offers.map((o) => o.approvalSpeed.index == fastestSpeedIndex).toList(),
              highlightLabel: 'Fastest',
            ),
            TableRow(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text('Key Benefits', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.subGrey)),
                ),
                for (final offer in offers)
                  Padding(
                    padding: const EdgeInsets.only(left: 10, top: 10, bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final benefit in offer.benefits)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $benefit', style: const TextStyle(fontSize: 11.5, color: AppColors.navy)),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _row(String label, List<String> values, {List<bool>? highlight, String? highlightLabel}) {
    return TableRow(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.subGrey)),
        ),
        for (int i = 0; i < values.length; i++)
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 12, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  values[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: (highlight != null && highlight[i]) ? AppColors.green : AppColors.navy,
                  ),
                ),
                if (highlight != null && highlight[i] && highlightLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(highlightLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.green)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
