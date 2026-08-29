import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../application/quiz_provider.dart';
import 'widgets/assessment_result_item.dart';

class AssessmentResultScreen extends ConsumerWidget {
  const AssessmentResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(assessmentProvider).result;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                  ),
                ],
              ),
            ),
            Expanded(
              child: result == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          "We couldn't find your assessment result. Please retake the assessment.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.subGrey),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Financial Habits',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.navy),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Here's a quick summary of your assessment result.",
                            style: TextStyle(fontSize: 13.5, color: AppColors.subGrey),
                          ),
                          const SizedBox(height: 24),
                          for (final categoryScore in result.categoryScores)
                            AssessmentResultItem(result: categoryScore),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: AppColors.greenTint, borderRadius: BorderRadius.circular(16)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb_outline, color: AppColors.green, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        result.isOverallPositive ? 'Keep up the good habits!' : 'There\'s room to build stronger habits',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        result.isOverallPositive
                                            ? 'These behaviours contribute to a stronger financial future.'
                                            : 'Small, consistent changes to these habits can strengthen your financial future.',
                                        style: const TextStyle(fontSize: 12.5, color: AppColors.subGrey, height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
