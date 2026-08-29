import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../consent/application/consent_provider.dart';
import '../data/models/assessment_result_model.dart';
import '../data/models/quiz_model.dart';
import '../data/repositories/quiz_repository.dart';

final quizRepositoryProvider = Provider<QuizRepository>((ref) => QuizRepository());

enum AssessmentStatus { loading, ready, submitting, completed, error }

class AssessmentState {
  final AssessmentStatus status;
  final List<AssessmentQuestion> questions;
  final int currentQuestionIndex;

  /// questionId -> selected optionId. A map (not a list) so an answer given
  /// on question 3 is still there if the user goes back from question 6.
  final Map<String, String> selectedAnswers;
  final AssessmentResult? result;
  final String? errorMessage;

  const AssessmentState({
    this.status = AssessmentStatus.loading,
    this.questions = const [],
    this.currentQuestionIndex = 0,
    this.selectedAnswers = const {},
    this.result,
    this.errorMessage,
  });

  AssessmentQuestion? get currentQuestion =>
      questions.isEmpty ? null : questions[currentQuestionIndex];

  String? get selectedOptionForCurrentQuestion => selectedAnswers[currentQuestion?.id];

  bool get isFirstQuestion => currentQuestionIndex == 0;

  bool get isLastQuestion => questions.isNotEmpty && currentQuestionIndex == questions.length - 1;

  /// 0..1, always derived from position — never hardcoded.
  double get progress => questions.isEmpty ? 0 : (currentQuestionIndex + 1) / questions.length;

  AssessmentState copyWith({
    AssessmentStatus? status,
    List<AssessmentQuestion>? questions,
    int? currentQuestionIndex,
    Map<String, String>? selectedAnswers,
    AssessmentResult? result,
    String? errorMessage,
  }) {
    return AssessmentState(
      status: status ?? this.status,
      questions: questions ?? this.questions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      result: result ?? this.result,
      errorMessage: errorMessage,
    );
  }
}

class AssessmentNotifier extends StateNotifier<AssessmentState> {
  AssessmentNotifier(this._repository, this._ref) : super(const AssessmentState());

  final QuizRepository _repository;
  final Ref _ref;

  Future<void> loadQuestions() async {
    // Starting fresh each time the intro flow is entered — answers from a
    // prior in-progress attempt shouldn't leak into a new one.
    state = const AssessmentState(status: AssessmentStatus.loading);
    try {
      final questions = await _repository.getQuestions();
      state = AssessmentState(status: AssessmentStatus.ready, questions: questions);
    } catch (_) {
      state = state.copyWith(
        status: AssessmentStatus.error,
        errorMessage: 'Unable to load the assessment. Please try again.',
      );
    }
  }

  void selectOption(String optionId) {
    final question = state.currentQuestion;
    if (question == null) return;
    state = state.copyWith(
      selectedAnswers: {...state.selectedAnswers, question.id: optionId},
    );
  }

  void nextQuestion() {
    if (state.isLastQuestion) return;
    state = state.copyWith(currentQuestionIndex: state.currentQuestionIndex + 1);
  }

  void previousQuestion() {
    if (state.isFirstQuestion) return;
    state = state.copyWith(currentQuestionIndex: state.currentQuestionIndex - 1);
  }

  /// Submits all answers, scores them, and — since this assessment doubles
  /// as the consent-granting flow for Psychometric Assessment — activates
  /// that consent. Returns false (without changing status away from
  /// submitting-safe) if a submission is already in flight, so a double tap
  /// can't fire it twice.
  Future<bool> submit() async {
    if (state.status == AssessmentStatus.submitting) return false;
    state = state.copyWith(status: AssessmentStatus.submitting);
    try {
      final result = await _repository.submitAssessment(state.selectedAnswers);
      await _ref.read(consentProvider.notifier).activateConsent(
            'psychometric-assessment',
            expiryDate: DateTime.now().add(const Duration(days: 180)),
          );
      state = state.copyWith(status: AssessmentStatus.completed, result: result);
      return true;
    } catch (_) {
      state = state.copyWith(
        status: AssessmentStatus.ready,
        errorMessage: 'Something went wrong while submitting. Please try again.',
      );
      return false;
    }
  }
}

final assessmentProvider = StateNotifierProvider<AssessmentNotifier, AssessmentState>((ref) {
  return AssessmentNotifier(ref.watch(quizRepositoryProvider), ref);
});
