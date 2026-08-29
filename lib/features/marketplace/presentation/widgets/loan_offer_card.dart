import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/loan_offer_model.dart';

class LoanOfferCard extends StatelessWidget {
  final LoanOffer offer;
  final VoidCallback onViewDetails;
  final bool isSelectedForCompare;
  final ValueChanged<bool> onCompareChanged;

  const LoanOfferCard({
    super.key,
    required this.offer,
    required this.onViewDetails,
    required this.isSelectedForCompare,
    required this.onCompareChanged,
  });

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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: offer.lenderColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(offer.lenderIcon, color: offer.lenderColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(offer.lenderName, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    const SizedBox(height: 2),
                    Text(offer.loanType, style: const TextStyle(fontSize: 12.5, color: AppColors.subGrey)),
                  ],
                ),
              ),
              if (offer.isFeatured) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.greenTint, borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 13, color: AppColors.green),
                      SizedBox(width: 3),
                      Text('Featured', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              _CompareCheckbox(isSelected: isSelectedForCompare, onChanged: onCompareChanged),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _DetailBlock(label: 'Loan Amount', value: _formatAmount(offer.loanAmount))),
              _blockDivider(),
              Expanded(child: _DetailBlock(label: 'Interest Rate', value: '${offer.interestRatePercent.toStringAsFixed(1)}% p.a.')),
              _blockDivider(),
              Expanded(child: _DetailBlock(label: 'Tenure', value: '${offer.tenureMonths} Months')),
              _blockDivider(),
              Expanded(child: _DetailBlock(label: 'EMI', value: _formatAmount(offer.emi))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (int i = 0; i < offer.benefits.length && i < 2; i++) ...[
                if (i != 0) ...[
                  const SizedBox(width: 8),
                  Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppColors.subGrey, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                ],
                const Icon(Icons.check_circle_outline, size: 14, color: AppColors.green),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    offer.benefits[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.subGrey),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: onViewDetails,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 14, color: AppColors.navy),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: onViewDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('View Offer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _blockDivider() => Container(width: 1, height: 28, color: AppColors.divider, margin: const EdgeInsets.symmetric(horizontal: 6));
}

class _DetailBlock extends StatelessWidget {
  final String label;
  final String value;
  const _DetailBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.subGrey)),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.navy),
        ),
      ],
    );
  }
}

class _CompareCheckbox extends StatelessWidget {
  final bool isSelected;
  final ValueChanged<bool> onChanged;
  const _CompareCheckbox({required this.isSelected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!isSelected),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue : Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: isSelected ? AppColors.blue : AppColors.cardBorder, width: 1.4),
        ),
        child: isSelected ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
      ),
    );
  }
}
