import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/application/auth_provider.dart';
import '../../profile/data/models/user_profile_model.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../application/dashboard_provider.dart';
import 'widgets/connected_data_card.dart';
import 'widgets/consent_status_card.dart';
import 'widgets/creditdna_hero_card.dart';
import 'widgets/dashboard_bottom_nav.dart';
import 'widgets/greeting_header.dart';
import 'widgets/income_snapshot_card.dart';
import 'widgets/next_step_card.dart';
import 'widgets/opportunities_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboard());
  }

  void _loadDashboard() {
    final userType = ref.read(userProfileProvider).profile?.userType ?? UserType.individual;
    ref.read(dashboardProvider.notifier).loadDashboard(userType: userType);
  }

  @override
  Widget build(BuildContext context) {
    // Logged out elsewhere (e.g. token expiry) -> back to login.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.user == null) {
        context.go('/login');
      }
    });

    final profileState = ref.watch(userProfileProvider);
    final authUser = ref.watch(authProvider).user;
    final firstName = profileState.firstName ??
        (authUser?.name != null && authUser!.name!.trim().isNotEmpty ? authUser.name!.trim().split(RegExp(r'\s+')).first : null);

    final dashboardState = ref.watch(dashboardProvider);
    final data = dashboardState.data;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const DashboardBottomNav(),
      body: SafeArea(
        bottom: false,
        child: data == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
            : RefreshIndicator(
                color: AppColors.blue,
                onRefresh: () async => _loadDashboard(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GreetingHeader(firstName: firstName),
                      const SizedBox(height: 22),
                      CreditDnaHeroCard(data: data.creditDna),
                      const SizedBox(height: 18),
                      NextStepCard(action: data.nextAction),
                      const SizedBox(height: 26),
                      ConnectedDataCard(items: data.connectedData),
                      const SizedBox(height: 26),
                      IncomeSnapshotCard(data: data.incomeSnapshot),
                      const SizedBox(height: 18),
                      const ConsentStatusCard(),
                      const SizedBox(height: 26),
                      OpportunitiesSection(opportunities: data.opportunities),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
