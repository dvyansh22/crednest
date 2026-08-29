import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/assessment_result_model.dart';
import '../../data/models/quiz_model.dart';

class AssessmentResultItem extends StatelessWidget {
  final CategoryScoreResult result;

  const AssessmentResultItem({super.key, required this.result});

  Color get _statusColor {
    switch (result.strength) {
      case HabitStrength.strong:
      case HabitStrength.good:
        return AppColors.green;
      case HabitStrength.average:
        return AppColors.gold;
      case HabitStrength.developing:
        return AppColors.subGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = result.category;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: category.color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(category.icon, size: 17, color: category.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.navy)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: result.progress,
                    minHeight: 5,
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation(_statusColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(
              result.strength.label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _statusColor),
            ),
          ),
        ],
      ),
    );
  }
}
