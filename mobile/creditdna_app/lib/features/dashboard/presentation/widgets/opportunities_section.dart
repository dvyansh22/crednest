import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/dashboard_models.dart';

class OpportunitiesSection extends StatelessWidget {
  final List<OpportunityPreview> opportunities;

  const OpportunitiesSection({super.key, required this.opportunities});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Opportunities for you', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 12),
        if (opportunities.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.explore_outlined, color: AppColors.subGrey, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Complete your financial profile to discover suitable opportunities.',
                    style: TextStyle(fontSize: 13, color: AppColors.subGrey, height: 1.4),
                  ),
                ),
              ],
            ),
          )
        else
          for (final offer in opportunities) _OpportunityCard(offer: offer),
      ],
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  final OpportunityPreview offer;
  const _OpportunityCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(offer.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 6),
                Text('Up to ₹${offer.maxAmount.round()}', style: const TextStyle(fontSize: 12.5, color: AppColors.subGrey)),
                Text(
                  'Starting from ${offer.startingRatePercent}% p.a.',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.subGrey),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push(offer.route),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('View offer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.blue)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 14, color: AppColors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
