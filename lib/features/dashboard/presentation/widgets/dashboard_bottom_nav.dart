import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';

class _NavTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String? route; // null for Home — it's the screen this bar lives on

  const _NavTab({required this.label, required this.icon, required this.activeIcon, this.route});
}

const _tabs = [
  _NavTab(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home_rounded, route: null),
  _NavTab(label: 'Insights', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, route: '/credit-dna-report'),
  _NavTab(label: 'Connect', icon: Icons.link_outlined, activeIcon: Icons.link_rounded, route: '/connect-bank'),
  _NavTab(label: 'Loans', icon: Icons.credit_card_outlined, activeIcon: Icons.credit_card, route: '/offers'),
  _NavTab(label: 'Profile', icon: Icons.person_outline, activeIcon: Icons.person, route: '/profile'),
];

class DashboardBottomNav extends StatelessWidget {
  const DashboardBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [for (int i = 0; i < _tabs.length; i++) _NavItem(tab: _tabs[i], isActive: i == 0)],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _NavTab tab;
  final bool isActive;

  const _NavItem({required this.tab, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.green : AppColors.subGrey;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: tab.route == null ? null : () => context.push(tab.route!),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? tab.activeIcon : tab.icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(tab.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
