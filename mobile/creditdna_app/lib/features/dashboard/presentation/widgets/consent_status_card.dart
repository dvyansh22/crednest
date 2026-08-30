import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';

class ConsentStatusCard extends StatelessWidget {
  const ConsentStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/connect-bank'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: AppColors.goldTint, shape: BoxShape.circle),
              child: const Icon(Icons.shield_outlined, color: AppColors.gold, size: 19),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Connect Bank', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  SizedBox(height: 3),
                  Text("You're in control of your data.", style: TextStyle(fontSize: 12.5, color: AppColors.subGrey)),
                  Text('Review and manage permissions anytime.', style: TextStyle(fontSize: 12.5, color: AppColors.subGrey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.subGrey),
          ],
        ),
      ),
    );
  }
}
