import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/application/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen for logout events and navigate back to login
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.user == null) {
        context.go('/login');
      }
    });

    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF102A43),
        title: const Text('CredNest Dashboard', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => ref.read(authProvider.notifier).logout(),
            tooltip: 'Log Out',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 80,
                color: Color(0xFF2E5FA3),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome, ${user?.name ?? "User"}!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF102A43),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user?.email ?? 'No email associated',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF5A6B7B),
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'Your financial story begins here.',
                style: TextStyle(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF5A6B7B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
