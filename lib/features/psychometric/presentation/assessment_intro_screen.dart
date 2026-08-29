import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../application/quiz_provider.dart';

/// Entry point for the Financial Habits Assessment — reached either from
/// the Dashboard's Next Step card or from Consent Center's "Provide
/// Consent" on Psychometric Assessment.
class AssessmentIntroScreen extends ConsumerWidget {
  const AssessmentIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Financial Habits\nAssessment',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.navy, height: 1.25),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'A quick assessment to understand your financial decision-making and money habits.',
                        style: TextStyle(fontSize: 14.5, color: AppColors.subGrey, height: 1.45),
                      ),
                      const SizedBox(height: 32),
                      const _InfoRow(icon: Icons.access_time, text: 'Takes about 2 minutes'),
                      const SizedBox(height: 20),
                      const _InfoRow(icon: Icons.list_alt_outlined, text: '8 questions'),
                      const SizedBox(height: 20),
                      const _InfoRow(icon: Icons.lock_outline, text: 'Your responses are private and secure'),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.blueTint,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.shield_outlined, color: AppColors.blue, size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'This helps us personalize your insights and improve your CredNest financial profile.',
                                style: TextStyle(fontSize: 13, color: AppColors.navy, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    await ref.read(assessmentProvider.notifier).loadQuestions();
                    if (context.mounted) context.push('/psychometric-quiz/questions');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Start Assessment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.subGrey),
        const SizedBox(width: 14),
        Text(text, style: const TextStyle(fontSize: 14.5, color: AppColors.navy, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
