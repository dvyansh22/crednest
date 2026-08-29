import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/profile/providers/user_profile_provider.dart';

/// Single place that decides where an authenticated user lands: Profile
/// Setup if they haven't completed it yet, Dashboard otherwise.
///
/// Used by splash (session restore), login, and signup so the branching
/// logic lives in exactly one place.
Future<void> navigateAfterAuthentication(BuildContext context, WidgetRef ref) async {
  await ref.read(userProfileProvider.notifier).loadProfile();
  if (!context.mounted) return;
  final isProfileCompleted = ref.read(userProfileProvider).isProfileCompleted;
  context.go(isProfileCompleted ? '/dashboard' : '/profile-setup');
}
