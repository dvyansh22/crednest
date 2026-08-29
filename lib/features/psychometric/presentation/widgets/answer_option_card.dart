import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/quiz_model.dart';

class AnswerOptionCard extends StatelessWidget {
  final AssessmentOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const AnswerOptionCard({
    super.key,
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.greenTint : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.green : AppColors.cardBorder, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.green : AppColors.fieldFill,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                option.id,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.subGrey,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                option.text,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.navy, height: 1.3),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, color: AppColors.green, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
