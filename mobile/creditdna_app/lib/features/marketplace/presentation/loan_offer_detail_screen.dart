import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../application/marketplace_provider.dart';
import '../data/models/loan_offer_model.dart';

class LoanOfferDetailScreen extends ConsumerWidget {
  final String offerId;
  final LoanOffer? initialOffer;

  const LoanOfferDetailScreen({super.key, required this.offerId, this.initialOffer});

  LoanOffer? _resolve(WidgetRef ref) {
    if (initialOffer != null) return initialOffer;
    for (final offer in ref.read(loanMarketplaceProvider).offers) {
      if (offer.id == offerId) return offer;
    }
    return null;
  }

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
    final offer = _resolve(ref);

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
                  Expanded(
                    child: Text(
                      offer?.lenderName ?? 'Offer Details',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: offer == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          "We couldn't find details for this offer.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.subGrey),
                        ),
                      ),
                    )
                  : _DetailBody(offer: offer, formatAmount: _formatAmount),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final LoanOffer offer;
  final String Function(double) formatAmount;
  const _DetailBody({required this.offer, required this.formatAmount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: offer.lenderColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(offer.lenderIcon, color: offer.lenderColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(offer.lenderName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
                          const SizedBox(height: 3),
                          Text(offer.loanType, style: const TextStyle(fontSize: 13, color: AppColors.subGrey)),
                        ],
                      ),
                    ),
                    if (offer.isFeatured)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: AppColors.greenTint, borderRadius: BorderRadius.circular(20)),
                        child: const Text('Featured', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green)),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                _SectionCard(
                  title: 'Loan summary',
                  child: Column(
                    children: [
                      _FigureRow(label: 'Loan Amount', value: formatAmount(offer.loanAmount)),
                      _FigureRow(label: 'Interest Rate', value: '${offer.interestRatePercent.toStringAsFixed(1)}% p.a.'),
                      _FigureRow(label: 'Tenure', value: '${offer.tenureMonths} Months'),
                      _FigureRow(label: 'Estimated EMI', value: formatAmount(offer.emi)),
                      _FigureRow(label: 'Processing Fee', value: '${formatAmount(offer.processingFeeAmount)} (${offer.processingFeePercent}%)'),
                      _FigureRow(label: 'Total Estimated Repayment', value: formatAmount(offer.totalEstimatedRepayment), isLast: true),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Benefits',
                  child: _BulletList(items: offer.benefits, icon: Icons.check_circle_outline, color: AppColors.green),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Eligibility requirements',
                  child: _BulletList(items: offer.eligibilityRequirements, icon: Icons.task_alt, color: AppColors.blue),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Required documents',
                  child: _BulletList(items: offer.requiredDocuments, icon: Icons.description_outlined, color: AppColors.navy),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Repayment information',
                  child: Text(offer.repaymentInformation, style: const TextStyle(fontSize: 13.5, color: AppColors.subGrey, height: 1.45)),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.divider))),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(loanApplicationProvider.notifier).startApplication(offer);
                  context.push('/offers/apply/review');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Apply for this loan', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _FigureRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  const _FigureRow({required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.subGrey))),
          Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.navy)),
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;
  final IconData icon;
  final Color color;
  const _BulletList({required this.items, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 10),
                Expanded(child: Text(item, style: const TextStyle(fontSize: 13.5, color: AppColors.navy, height: 1.3))),
              ],
            ),
          ),
      ],
    );
  }
}
