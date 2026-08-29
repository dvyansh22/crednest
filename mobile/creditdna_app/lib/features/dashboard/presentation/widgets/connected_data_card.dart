import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/dashboard_models.dart';

class ConnectedDataCard extends StatelessWidget {
  final List<ConnectedDataItem> items;

  const ConnectedDataCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Your connected data',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => context.push('/consent'),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View all', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.blue)),
                  SizedBox(width: 3),
                  Icon(Icons.arrow_forward, size: 13, color: AppColors.blue),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _ConnectedDataRow(item: items[i]),
                if (i != items.length - 1) const Divider(height: 1, indent: 18, endIndent: 18, color: AppColors.divider),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ConnectedDataRow extends StatelessWidget {
  final ConnectedDataItem item;
  const _ConnectedDataRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final isPositive = item.status == ConnectionStatus.connected || item.status == ConnectionStatus.verified;
    final statusColor = switch (item.status) {
      ConnectionStatus.connected => AppColors.green,
      ConnectionStatus.verified => AppColors.blue,
      ConnectionStatus.notConnected => AppColors.subGrey,
      ConnectionStatus.expired => AppColors.gold,
      ConnectionStatus.revoked => AppColors.errorRed,
    };

    return InkWell(
      onTap: () => context.push(item.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: AppColors.blueTint, borderRadius: BorderRadius.circular(12)),
              child: Icon(item.icon, size: 18, color: AppColors.blue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(item.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
            ),
            Text(
              item.status.label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: statusColor),
            ),
            const SizedBox(width: 6),
            if (isPositive)
              Icon(Icons.check_circle, size: 17, color: statusColor)
            else
              const SizedBox(width: 17),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.subGrey),
          ],
        ),
      ),
    );
  }
}
