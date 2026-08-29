import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/score_model.dart';

class FinancialFactorRow extends StatelessWidget {
  final FinancialFactorModel factor;
  final VoidCallback onTap;

  const FinancialFactorRow({super.key, required this.factor, required this.onTap});

  Color get _color {
    switch (factor.colorType) {
      case FactorColorType.positive:
        return AppColors.green;
      case FactorColorType.moderate:
        return AppColors.gold;
      case FactorColorType.attention:
        return AppColors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAvailable = factor.dataAvailability == FactorDataAvailability.available;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: (isAvailable ? _color : AppColors.subGrey).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(factor.icon, size: 16, color: isAvailable ? _color : AppColors.subGrey),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    factor.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.navy),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    factor.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.subGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: isAvailable
                  ? Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value: factor.progress,
                              minHeight: 6,
                              backgroundColor: AppColors.divider,
                              valueColor: AlwaysStoppedAnimation(_color),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 46,
                          child: Text(
                            '${factor.score}/${factor.maxScore}',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.navy),
                          ),
                        ),
                      ],
                    )
                  : const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Not connected',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.subGrey),
                      ),
                    ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.subGrey),
          ],
        ),
      ),
    );
  }
}
