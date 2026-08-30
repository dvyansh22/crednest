import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Shown once, after a fresh login/signup, before ever triggering the real
/// native permission dialog. Returns true if the user chose "Allow
/// Location" (caller is responsible for then requesting the actual OS
/// permission), false for "Not Now".
Future<bool> showLocationPermissionDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(color: AppColors.greenTint, shape: BoxShape.circle),
              child: const Icon(Icons.location_on_outlined, color: AppColors.green, size: 28),
            ),
            const SizedBox(height: 18),
            const Text(
              'Enable Location Access',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
            const SizedBox(height: 10),
            const Text(
              'Location helps us verify account activity and improve the accuracy of your financial profile.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.subGrey, height: 1.45),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.blueTint, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, size: 15, color: AppColors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your location is accessed only with your permission. You can manage this anytime from the Consent Center.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.navy, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.subGrey,
                        side: const BorderSide(color: AppColors.cardBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Not Now', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Allow Location', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
