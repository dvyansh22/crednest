import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class ConsentSummaryCard extends StatelessWidget {
  final String overallLabel;
  final int activeCount;
  final int totalCount;
  final double activePercent; // 0..1

  const ConsentSummaryCard({
    super.key,
    required this.overallLabel,
    required this.activeCount,
    required this.totalCount,
    required this.activePercent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.greenTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.shield_outlined, color: AppColors.green, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Overall consent status', style: TextStyle(fontSize: 12.5, color: AppColors.subGrey)),
                const SizedBox(height: 2),
                Text(overallLabel, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.green)),
                const SizedBox(height: 2),
                Text(
                  '$activeCount of $totalCount consents active',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.subGrey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 68,
                  height: 68,
                  child: CircularProgressIndicator(
                    value: activePercent,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    backgroundColor: AppColors.divider,
                    valueColor: const AlwaysStoppedAnimation(AppColors.green),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(activePercent * 100).round()}%',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                    const Text('Active', style: TextStyle(fontSize: 9.5, color: AppColors.subGrey)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
