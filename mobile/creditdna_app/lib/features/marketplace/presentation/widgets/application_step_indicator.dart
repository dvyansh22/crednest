import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

const List<String> kApplicationSteps = ['Review Details', 'Confirm Consent', 'Submit'];

class ApplicationStepIndicator extends StatelessWidget {
  final int currentStep; // 0-based

  const ApplicationStepIndicator({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < kApplicationSteps.length; i++) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= currentStep ? AppColors.navy : AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  kApplicationSteps[i],
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: i == currentStep ? FontWeight.w700 : FontWeight.w500,
                    color: i <= currentStep ? AppColors.navy : AppColors.subGrey,
                  ),
                ),
              ],
            ),
          ),
          if (i != kApplicationSteps.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
