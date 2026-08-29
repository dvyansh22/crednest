import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../application/quiz_provider.dart';
import '../data/models/quiz_model.dart';
import 'widgets/answer_option_card.dart';
import 'widgets/assessment_progress_bar.dart';

class AssessmentQuestionScreen extends ConsumerWidget {
  const AssessmentQuestionScreen({super.key});

  Future<void> _handleSubmit(BuildContext context, WidgetRef ref) async {
    final success = await ref.read(assessmentProvider.notifier).submit();
    if (!context.mounted) return;
    if (success) {
      context.push('/psychometric-quiz/complete');
    } else {
      final message = ref.read(assessmentProvider).errorMessage ?? 'Something went wrong. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assessmentProvider);

    if (state.status == AssessmentStatus.loading || state.currentQuestion == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.blue)),
      );
    }

    final question = state.currentQuestion!;
    final selectedOptionId = state.selectedOptionForCurrentQuestion;
    final isSubmitting = state.status == AssessmentStatus.submitting;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (state.isFirstQuestion) {
                        context.pop();
                      } else {
                        ref.read(assessmentProvider.notifier).previousQuestion();
                      }
                    },
                    icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                  ),
                  const Spacer(),
                  Text(
                    '${state.currentQuestionIndex + 1} of ${state.questions.length}',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.subGrey),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AssessmentProgressBar(progress: state.progress),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.category.sectionLabel,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      question.question,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: AppColors.navy, height: 1.3),
                    ),
                    const SizedBox(height: 24),
                    for (final option in question.options) ...[
                      AnswerOptionCard(
                        option: option,
                        isSelected: option.id == selectedOptionId,
                        onTap: () => ref.read(assessmentProvider.notifier).selectOption(option.id),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                children: [
                  if (!state.isFirstQuestion) ...[
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: OutlinedButton(
                          onPressed: isSubmitting ? null : () => ref.read(assessmentProvider.notifier).previousQuestion(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.navy,
                            side: const BorderSide(color: AppColors.cardBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_back, size: 17),
                              SizedBox(width: 6),
                              Text('Previous', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: state.isFirstQuestion ? 1 : 1,
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: selectedOptionId == null || isSubmitting
                            ? null
                            : () {
                                if (state.isLastQuestion) {
                                  _handleSubmit(context, ref);
                                } else {
                                  ref.read(assessmentProvider.notifier).nextQuestion();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      state.isLastQuestion ? 'Submit Assessment' : 'Continue',
                                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_forward, size: 17),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
