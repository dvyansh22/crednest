import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Confirms before revoking — returns true if the user confirmed, false/null
/// otherwise. Revoking is never immediate from a single tap.
Future<bool> showRevokeConsentDialog(BuildContext context, {required String consentTitle}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Revoke $consentTitle access?', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 17)),
      content: const Text(
        'CredNest will stop using this data for future financial assessments. '
        'This may affect your CreditDNA profile.',
        style: TextStyle(color: AppColors.subGrey, height: 1.4, fontSize: 13.5),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.subGrey, fontWeight: FontWeight.w600)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Revoke', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
