import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../location/application/location_provider.dart';
import '../../../location/data/models/location_model.dart';
import '../../data/models/consent_model.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDateTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${_monthNames[date.month - 1]} ${date.year}, $hour:$minute';
}

/// Replaces the generic [ConsentItemCard] for the 'location-data' row.
/// Unlike other consents (which are simple active/inactive toggles), this
/// one has real OS-permission and device-GPS states to represent — so it's
/// driven directly by [LocationState] rather than the generic consent
/// status alone.
class LocationConsentCard extends StatelessWidget {
  final ConsentModel consent;
  final LocationState locationState;
  final VoidCallback onEnable;
  final VoidCallback onRefresh;
  final VoidCallback onOpenAppSettings;
  final VoidCallback onOpenLocationSettings;
  final VoidCallback onManage;

  const LocationConsentCard({
    super.key,
    required this.consent,
    required this.locationState,
    required this.onEnable,
    required this.onRefresh,
    required this.onOpenAppSettings,
    required this.onOpenLocationSettings,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                    const SizedBox(height: 2),
                    Text(consent.purpose, style: const TextStyle(fontSize: 11.5, color: AppColors.subGrey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (locationState.status) {
      case LocationStatus.available:
        final model = locationState.model;
        if (model != null && model.hasResolvedPlace) {
          return _activeState(model);
        }
        return _notConnectedState(
          description: "We couldn't resolve a readable location from your device just yet.",
          actionLabel: 'Try Again',
          onAction: onRefresh,
        );

      case LocationStatus.locationServicesDisabled:
        return _statusBlock(
          statusLabel: 'Location Services Off',
          statusColor: AppColors.gold,
          description: 'Turn on location services to retrieve your current location.',
          actionLabel: 'Open Location Settings',
          onAction: onOpenLocationSettings,
        );

      case LocationStatus.permissionPermanentlyDenied:
        return _statusBlock(
          statusLabel: 'Permission Blocked',
          statusColor: AppColors.errorRed,
          description: 'Location permission is disabled in your device settings.',
          actionLabel: 'Open App Settings',
          onAction: onOpenAppSettings,
        );

      case LocationStatus.checkingPermission:
      case LocationStatus.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.blue)),
              SizedBox(width: 12),
              Text('Checking location…', style: TextStyle(fontSize: 12.5, color: AppColors.subGrey)),
            ],
          ),
        );

      case LocationStatus.error:
        return _notConnectedState(
          description: locationState.errorMessage ?? 'Unable to determine your location right now.',
          actionLabel: 'Try Again',
          onAction: onEnable,
        );

      case LocationStatus.initial:
      case LocationStatus.permissionRequired:
      case LocationStatus.permissionDenied:
        return _notConnectedState(
          description: 'Location access has not been enabled.',
          actionLabel: 'Enable Location',
          onAction: onEnable,
        );
    }
  }

  Widget _activeState(LocationModel model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            const Text('Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green)),
          ],
        ),
        const SizedBox(height: 10),
        const Text('Current Location', style: TextStyle(fontSize: 11, color: AppColors.subGrey)),
        const SizedBox(height: 2),
        Text(model.readableLocation, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy)),
        if (model.lastUpdated != null) ...[
          const SizedBox(height: 8),
          Text('Last updated ${_formatDateTime(model.lastUpdated!)}', style: const TextStyle(fontSize: 11, color: AppColors.subGrey)),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onRefresh,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navy,
                  side: const BorderSide(color: AppColors.cardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Refresh Location', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextButton(
                onPressed: onManage,
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                child: const Text('Manage Permission', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.errorRed)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _notConnectedState({required String description, required String actionLabel, required VoidCallback onAction}) {
    return _statusBlock(
      statusLabel: 'Not Connected',
      statusColor: AppColors.subGrey,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  Widget _statusBlock({
    required String statusLabel,
    required Color statusColor,
    required String description,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(statusLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: statusColor)),
          ],
        ),
        const SizedBox(height: 8),
        Text(description, style: const TextStyle(fontSize: 12.5, color: AppColors.subGrey, height: 1.4)),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(actionLabel, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
