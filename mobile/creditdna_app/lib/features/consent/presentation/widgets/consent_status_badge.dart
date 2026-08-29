import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/consent_model.dart';

Color colorForConsentStatus(ConsentStatus status) {
  switch (status) {
    case ConsentStatus.active:
      return AppColors.green;
    case ConsentStatus.inactive:
      return AppColors.subGrey;
    case ConsentStatus.expired:
      return AppColors.gold;
    case ConsentStatus.revoked:
      return AppColors.errorRed;
  }
}

/// Small inline "Active" / "Inactive" / etc. label used next to the expiry
/// text on a consent row — deliberately plain text, not a filled pill, to
/// match the reference layout.
class ConsentStatusBadge extends StatelessWidget {
  final ConsentStatus status;

  const ConsentStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Text(
      status.label,
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colorForConsentStatus(status)),
    );
  }
}
