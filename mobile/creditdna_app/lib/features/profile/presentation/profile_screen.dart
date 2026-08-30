import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/application/auth_provider.dart';
import '../data/models/user_profile_model.dart';
import '../providers/user_profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).profile;
    final authUser = ref.watch(authProvider).user;
    final displayName = profile?.fullName.isNotEmpty == true ? profile!.fullName : (authUser?.name ?? '');
    final initial = displayName.isNotEmpty ? displayName.trim()[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Profile', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.navy),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.blueTint,
                    child: Text(
                      initial,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.blue),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    displayName.isNotEmpty ? displayName : 'Your profile',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  if (profile?.email.isNotEmpty == true || authUser?.email != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      profile?.email ?? authUser?.email ?? '',
                      style: const TextStyle(fontSize: 14, color: AppColors.subGrey),
                    ),
                  ],
                  if (profile != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.greenTint, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        profile.userType.label,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.green),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            _ProfileTile(
              icon: Icons.edit_outlined,
              title: 'Edit profile',
              onTap: () => context.push('/profile-setup'),
            ),
            _ProfileTile(
              icon: Icons.account_balance_outlined,
              title: 'Connect bank',
              onTap: () => context.push('/connect-bank'),
            ),
            _ProfileTile(
              icon: Icons.receipt_long_outlined,
              title: 'Data benefit ledger',
              onTap: () => context.push('/ledger'),
            ),
            const SizedBox(height: 20),
            _ProfileTile(
              icon: Icons.logout,
              title: 'Log out',
              iconColor: AppColors.errorRed,
              textColor: AppColors.errorRed,
              onTap: () {
                ref.read(userProfileProvider.notifier).reset();
                ref.read(authProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? AppColors.subGrey),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: textColor ?? AppColors.navy)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.subGrey),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
