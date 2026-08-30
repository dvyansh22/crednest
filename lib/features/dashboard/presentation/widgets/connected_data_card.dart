import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../location/application/location_provider.dart';
import '../../data/models/dashboard_models.dart';

class ConnectedDataCard extends ConsumerWidget {
  final List<ConnectedDataItem> items;

  const ConnectedDataCard({super.key, required this.items});

  /// The Location row is derived live from [locationProvider] rather than
  /// the (static, per-load) dashboard data — so it updates immediately
  /// when permission/location state changes, without needing a dashboard
  /// reload.
  ConnectedDataItem _locationItem(LocationState locationState) {
    final model = locationState.model;
    final isActive = locationState.status == LocationStatus.available && (model?.hasResolvedPlace ?? false);
    return ConnectedDataItem(
      title: 'Location',
      icon: Icons.location_on_outlined,
      status: isActive ? ConnectionStatus.connected : ConnectionStatus.notConnected,
      route: '/consent',
      subtitle: isActive ? model!.readableLocation : null,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationProvider);
    final allItems = [...items, _locationItem(locationState)];
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
              for (int i = 0; i < allItems.length; i++) ...[
                _ConnectedDataRow(item: allItems[i]),
                if (i != allItems.length - 1) const Divider(height: 1, indent: 18, endIndent: 18, color: AppColors.divider),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.subGrey),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
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
