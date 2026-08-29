import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/score_model.dart';

class ReportActionCard extends StatelessWidget {
  final RecommendationModel recommendation;
  final VoidCallback onTap;

  const ReportActionCard({super.key, required this.recommendation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: AppColors.blueTint, shape: BoxShape.circle),
              child: Icon(recommendation.icon, size: 16, color: AppColors.blue),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommendation.title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    recommendation.description,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.subGrey, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.subGrey),
          ],
        ),
      ),
    );
  }
}
