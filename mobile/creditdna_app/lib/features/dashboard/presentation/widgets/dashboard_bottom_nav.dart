import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';

class _NavTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const _NavTab({required this.label, required this.icon, required this.activeIcon, required this.route});
}

const _tabs = [
  _NavTab(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home_rounded, route: '/dashboard'),
  _NavTab(label: 'Insights', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, route: '/credit-dna-report'),
  _NavTab(label: 'Connect', icon: Icons.link_outlined, activeIcon: Icons.link_rounded, route: '/connect-bank'),
  _NavTab(label: 'Loans', icon: Icons.credit_card_outlined, activeIcon: Icons.credit_card, route: '/offers'),
  _NavTab(label: 'Profile', icon: Icons.person_outline, activeIcon: Icons.person, route: '/profile'),
];

/// Shared bottom navigation bar shown on every top-level destination
/// (Home, Financial Report, ...). [currentIndex] marks which tab is active
/// so it stays visually correct no matter which screen hosts the bar.
class DashboardBottomNav extends StatelessWidget {
  final int currentIndex;

  const DashboardBottomNav({super.key, required this.currentIndex});

  void _handleTap(BuildContext context, int index) {
    if (index == currentIndex) return; // already on this tab

    if (index == 0) {
      // Home is always directly beneath every other tab's screen in the
      // stack (each is pushed straight from Home) — pop back to it rather
      // than pushing a second Dashboard instance. Falls back to go() if
      // there's ever nothing to pop, so this can never dead-end.
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(_tabs[0].route);
      }
      return;
    }

    context.push(_tabs[index].route);
  }

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
            children: [
              for (int i = 0; i < _tabs.length; i++)
                _NavItem(
                  tab: _tabs[i],
                  isActive: i == currentIndex,
                  onTap: () => _handleTap(context, i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _NavTab tab;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({required this.tab, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.green : AppColors.subGrey;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
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
