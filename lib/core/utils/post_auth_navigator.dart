import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/location/application/location_provider.dart';
import '../../features/location/data/location_popup_storage.dart';
import '../../features/location/presentation/widgets/location_permission_dialog.dart';
import '../../features/profile/providers/user_profile_provider.dart';

/// Single place that decides where an authenticated user lands: Profile
/// Setup if they haven't completed it yet, Dashboard otherwise.
///
/// Used by splash (session restore), login, and signup so the branching
/// logic lives in exactly one place. [isFreshAuth] should be true only for
/// a just-completed login/signup — it gates the one-time location
/// explanation popup so returning users (session restore via splash)
/// aren't re-prompted on every app open.
Future<void> navigateAfterAuthentication(
  BuildContext context,
  WidgetRef ref, {
  bool isFreshAuth = false,
}) async {
  await ref.read(userProfileProvider.notifier).loadProfile();
  if (!context.mounted) return;
  final isProfileCompleted = ref.read(userProfileProvider).isProfileCompleted;

  if (isFreshAuth) {
    await _maybeShowLocationPrompt(context, ref);
    if (!context.mounted) return;
  }

  context.go(isProfileCompleted ? '/dashboard' : '/profile-setup');
}

Future<void> _maybeShowLocationPrompt(BuildContext context, WidgetRef ref) async {
  final popupStorage = LocationPopupStorage();
  if (await popupStorage.hasShownPopup()) return;

  final locationNotifier = ref.read(locationProvider.notifier);
  // Reads current permission/service state; if already granted this also
  // refreshes the real location, so the explanation popup below only ever
  // appears when permission genuinely hasn't been decided yet.
  await locationNotifier.checkPermissionState();
  if (!context.mounted) return;

  if (ref.read(locationProvider).status != LocationStatus.permissionRequired) {
    await popupStorage.markPopupShown();
    return;
  }

  await popupStorage.markPopupShown();
  if (!context.mounted) return;
  final allow = await showLocationPermissionDialog(context);
  if (!context.mounted) return;
  if (allow) {
    await locationNotifier.requestPermission();
  }
}
