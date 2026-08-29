import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/loan_offer_model.dart';

/// Compact per-offer header used atop each column of the comparison table.
class CompareOfferCard extends StatelessWidget {
  final LoanOffer offer;
  final VoidCallback onRemove;
  final VoidCallback onView;

  const CompareOfferCard({super.key, required this.offer, required this.onRemove, required this.onView});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: offer.lenderColor.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(offer.lenderIcon, size: 16, color: offer.lenderColor),
            ),
            const Spacer(),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: AppColors.subGrey),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          offer.lenderName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy),
        ),
        const SizedBox(height: 2),
        Text(offer.loanType, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.subGrey)),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: OutlinedButton(
            onPressed: onView,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navy,
              side: const BorderSide(color: AppColors.cardBorder),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('View Offer', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
