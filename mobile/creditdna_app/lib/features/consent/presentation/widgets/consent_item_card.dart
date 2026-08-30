import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/consent_model.dart';
import 'consent_status_badge.dart';

class ConsentItemCard extends StatelessWidget {
  final ConsentModel consent;
  final VoidCallback onTap;
  final VoidCallback onAction;

  const ConsentItemCard({
    super.key,
    required this.consent,
    required this.onTap,
    required this.onAction,
  });

  String get _infoText {
    switch (consent.status) {
      case ConsentStatus.active:
        final days = consent.daysUntilExpiry ?? 0;
        return 'Expires in $days ${days == 1 ? 'day' : 'days'}';
      case ConsentStatus.inactive:
        return 'Consent not provided';
      case ConsentStatus.expired:
        return 'Expired';
      case ConsentStatus.revoked:
        return 'Revoked';
    }
  }

  String get _actionLabel {
    switch (consent.status) {
      case ConsentStatus.active:
        return 'Disconnect';
      case ConsentStatus.expired:
      case ConsentStatus.inactive:
      case ConsentStatus.revoked:
        return 'Connect';
    }
  }

  Color get _actionColor => consent.status == ConsentStatus.active ? AppColors.errorRed : AppColors.blue;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: consent.accentColor.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(consent.icon, color: consent.accentColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(consent.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      const SizedBox(height: 6),
                      const Text('Purpose', style: TextStyle(fontSize: 11.5, color: AppColors.subGrey)),
                      Text(
                        consent.purpose,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.navy),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _infoText,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.subGrey),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('•', style: TextStyle(fontSize: 12.5, color: AppColors.subGrey.withValues(alpha: 0.6))),
                      const SizedBox(width: 6),
                      ConsentStatusBadge(status: consent.status),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    backgroundColor: _actionColor.withValues(alpha: 0.1),
                    foregroundColor: _actionColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    _actionLabel,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
