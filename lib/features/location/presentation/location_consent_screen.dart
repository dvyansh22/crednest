import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../application/location_provider.dart';
import '../data/models/location_model.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDateTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${_monthNames[date.month - 1]} ${date.year}, $hour:$minute';
}

class LocationConsentScreen extends ConsumerStatefulWidget {
  const LocationConsentScreen({super.key});

  @override
  ConsumerState<LocationConsentScreen> createState() => _LocationConsentScreenState();
}

class _LocationConsentScreenState extends ConsumerState<LocationConsentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationProvider.notifier).checkPermissionState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Location Consent',
          style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _buildBody(context, locationState),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, LocationState locationState) {
    final notifier = ref.read(locationProvider.notifier);

    switch (locationState.status) {
      case LocationStatus.checkingPermission:
      case LocationStatus.loading:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              height: 40,
              width: 40,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.blue),
            ),
            const SizedBox(height: 20),
            Text(
              locationState.status == LocationStatus.checkingPermission
                  ? 'Checking location permission…'
                  : 'Retrieving device coordinates…',
              style: const TextStyle(fontSize: 14, color: AppColors.subGrey, fontWeight: FontWeight.w500),
            ),
          ],
        );

      case LocationStatus.available:
        final model = locationState.model;
        if (model != null && model.hasResolvedPlace) {
          return _buildAvailableUI(context, model, notifier);
        }
        return _buildErrorUI(
          context,
          title: "Couldn't Resolve Location",
          description: "We fetched your coordinates but couldn't resolve a readable address. Please try refreshing.",
          actionLabel: 'Try Again',
          onAction: notifier.refreshLocation,
        );

      case LocationStatus.locationServicesDisabled:
        return _buildErrorUI(
          context,
          icon: Icons.location_off_outlined,
          iconColor: AppColors.gold,
          iconBg: AppColors.goldTint,
          title: 'Location Services Off',
          description: 'Turn on location services in your device settings to enable location access.',
          actionLabel: 'Open Location Settings',
          onAction: notifier.openLocationSettings,
        );

      case LocationStatus.permissionPermanentlyDenied:
        return _buildErrorUI(
          context,
          icon: Icons.block_outlined,
          iconColor: AppColors.errorRed,
          iconBg: AppColors.redTint,
          title: 'Permission Blocked',
          description: 'Location access is disabled in your device settings. Please enable it in App Settings.',
          actionLabel: 'Open App Settings',
          onAction: notifier.openAppSettings,
        );

      case LocationStatus.error:
        return _buildErrorUI(
          context,
          title: 'Verification Failed',
          description: locationState.errorMessage ?? 'Unable to determine your location right now.',
          actionLabel: 'Try Again',
          onAction: notifier.requestPermission,
        );

      case LocationStatus.initial:
      case LocationStatus.permissionRequired:
      case LocationStatus.permissionDenied:
        return _buildRequestUI(context, notifier);
    }
  }

  Widget _buildRequestUI(BuildContext context, LocationNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: AppColors.greenTint, shape: BoxShape.circle),
            child: const Icon(Icons.location_on_outlined, color: AppColors.green, size: 30),
          ),
          const SizedBox(height: 20),
          const Text(
            'Enable Location Access',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
          ),
          const SizedBox(height: 12),
          const Text(
            'Location helps us verify account activity and improve the accuracy of your financial profile.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.subGrey, height: 1.45),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.blueTint, borderRadius: BorderRadius.circular(14)),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 16, color: AppColors.blue),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your location is accessed only with your permission. You can manage this anytime from the Consent Center.',
                    style: TextStyle(fontSize: 12, color: AppColors.navy, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.subGrey,
                      side: const BorderSide(color: AppColors.cardBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Not Now', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => notifier.requestPermission(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Allow', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableUI(BuildContext context, LocationModel model, LocationNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: AppColors.greenTint, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline, color: AppColors.green, size: 32),
          ),
          const SizedBox(height: 20),
          const Text(
            'Location Connected',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your device coordinates are successfully verified and mapped to your account.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: AppColors.subGrey, height: 1.4),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 20),
          _buildInfoRow('Locality', model.readableLocation),
          const SizedBox(height: 12),
          if (model.latitude != null && model.longitude != null) ...[
            _buildInfoRow('Coordinates', '${model.latitude!.toStringAsFixed(5)}, ${model.longitude!.toStringAsFixed(5)}'),
            const SizedBox(height: 12),
          ],
          if (model.lastUpdated != null) ...[
            _buildInfoRow('Last Verified', _formatDateTime(model.lastUpdated!)),
            const SizedBox(height: 20),
          ],
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Done', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => notifier.refreshLocation(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: const BorderSide(color: AppColors.cardBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Refresh', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextButton(
                    onPressed: () => notifier.disableLocation(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.errorRed,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Disable Access', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.subGrey),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorUI(
    BuildContext context, {
    IconData icon = Icons.error_outline,
    Color iconColor = AppColors.subGrey,
    Color iconBg = AppColors.divider,
    required String title,
    required String description,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.subGrey, height: 1.45),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.subGrey,
                      side: const BorderSide(color: AppColors.cardBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(actionLabel, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
