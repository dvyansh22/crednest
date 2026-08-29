import '../models/assessment_result_model.dart';
import '../models/quiz_model.dart';

/// Serves the assessment questions and scores completed answers.
///
/// No backend exists yet — [getQuestions] and [submitAssessment] return
/// local data shaped like the eventual API response. Swap their bodies for
/// real calls (POST /assessment/start, POST /assessment/answer,
/// POST /assessment/submit, GET /assessment/result) without touching any
/// caller.
///
/// IMPORTANT: [_scoreAnswers] is a clearly isolated, temporary prototype
/// scoring model (A=4 .. D=1 points, averaged per category). It is NOT a
/// validated psychometric or credit-risk instrument — it exists so the UI
/// has something real to render until a backend/ML scoring service replaces
/// this method's body.
class QuizRepository {
  Future<List<AssessmentQuestion>> getQuestions() async {
    // TODO(backend): replace with POST /assessment/start
    await Future.delayed(const Duration(milliseconds: 300));
    return _questions;
  }

  Future<AssessmentResult> submitAssessment(Map<String, String> answers) async {
    // TODO(backend): replace with POST /assessment/submit + GET /assessment/result
    await Future.delayed(const Duration(milliseconds: 900));
    return _scoreAnswers(answers);
  }

  AssessmentResult _scoreAnswers(Map<String, String> answers) {
    final pointsByCategory = <AssessmentCategory, List<int>>{};

    for (final question in _questions) {
      final selectedOptionId = answers[question.id];
      if (selectedOptionId == null) continue;
      final option = question.options.firstWhere((o) => o.id == selectedOptionId);
      pointsByCategory.putIfAbsent(question.category, () => []).add(option.points);
    }

    final categoryScores = pointsByCategory.entries.map((entry) {
      final average = entry.value.reduce((a, b) => a + b) / entry.value.length;
      return CategoryScoreResult(
        category: entry.key,
        averagePoints: average,
        progress: ((average - 1) / 3).clamp(0.0, 1.0),
        strength: _strengthFor(average),
      );
    }).toList();

    // Keep category order stable and matching question order for a
    // predictable summary screen.
    categoryScores.sort(
      (a, b) => _questions.indexWhere((q) => q.category == a.category).compareTo(
            _questions.indexWhere((q) => q.category == b.category),
          ),
    );

    return AssessmentResult(categoryScores: categoryScores, completedAt: DateTime.now());
  }

  HabitStrength _strengthFor(double averagePoints) {
    if (averagePoints >= 3.5) return HabitStrength.strong;
    if (averagePoints >= 2.75) return HabitStrength.good;
    if (averagePoints >= 2.0) return HabitStrength.average;
    return HabitStrength.developing;
  }

  static const _questions = [
    AssessmentQuestion(
      id: 'q1',
      category: AssessmentCategory.spendingHabits,
      question: 'How do you usually manage your monthly expenses?',
      options: [
        AssessmentOption(id: 'A', text: 'I plan them in advance', points: 4),
        AssessmentOption(id: 'B', text: 'I have a rough idea of my expenses', points: 3),
        AssessmentOption(id: 'C', text: 'I spend as needed and check later', points: 2),
        AssessmentOption(id: 'D', text: 'I rarely track my expenses', points: 1),
      ],
    ),
    AssessmentQuestion(
      id: 'q2',
      category: AssessmentCategory.savingPlanning,
      question: 'If you receive extra income this month, what would you most likely do?',
      options: [
        AssessmentOption(id: 'A', text: 'Save most of it', points: 4),
        AssessmentOption(id: 'B', text: 'Pay existing financial commitments', points: 3),
        AssessmentOption(id: 'C', text: 'Split it between saving and spending', points: 2),
        AssessmentOption(id: 'D', text: 'Spend most of it', points: 1),
      ],
    ),
    AssessmentQuestion(
      id: 'q3',
      category: AssessmentCategory.financialResilience,
      question: 'An unexpected expense of ₹10,000 comes up. What would you do first?',
      options: [
        AssessmentOption(id: 'A', text: 'Use my savings', points: 4),
        AssessmentOption(id: 'B', text: 'Reduce other expenses', points: 3),
        AssessmentOption(id: 'C', text: 'Use available credit', points: 2),
        AssessmentOption(id: 'D', text: 'Borrow from someone', points: 1),
      ],
    ),
    AssessmentQuestion(
      id: 'q4',
      category: AssessmentCategory.borrowingAwareness,
      question: 'Before taking a loan, what do you usually consider?',
      options: [
        AssessmentOption(id: 'A', text: 'Interest rate, fees, and repayment amount', points: 4),
        AssessmentOption(id: 'B', text: 'Mainly the monthly EMI', points: 3),
        AssessmentOption(id: 'C', text: 'Mainly how quickly I can get the loan', points: 2),
        AssessmentOption(id: 'D', text: "I don't usually compare the terms", points: 1),
      ],
    ),
    AssessmentQuestion(
      id: 'q5',
      category: AssessmentCategory.financialAwareness,
      question: 'How often do you check your bank transactions?',
      options: [
        AssessmentOption(id: 'A', text: 'Regularly', points: 4),
        AssessmentOption(id: 'B', text: 'Once or twice a month', points: 3),
        AssessmentOption(id: 'C', text: 'Only when I need to', points: 2),
        AssessmentOption(id: 'D', text: 'Rarely', points: 1),
      ],
    ),
    AssessmentQuestion(
      id: 'q6',
      category: AssessmentCategory.financialResilience,
      question: 'If your income decreases temporarily, what would you most likely do?',
      options: [
        AssessmentOption(id: 'A', text: 'Reduce non-essential spending', points: 4),
        AssessmentOption(id: 'B', text: 'Use some of my savings', points: 3),
        AssessmentOption(id: 'C', text: 'Continue spending normally', points: 2),
        AssessmentOption(id: 'D', text: 'Borrow money to maintain my spending', points: 1),
      ],
    ),
    AssessmentQuestion(
      id: 'q7',
      category: AssessmentCategory.decisionMaking,
      question: 'When making a major financial purchase, how do you decide?',
      options: [
        AssessmentOption(id: 'A', text: 'Compare options and consider my budget', points: 4),
        AssessmentOption(id: 'B', text: 'Research one or two options', points: 3),
        AssessmentOption(id: 'C', text: 'Choose based mainly on price', points: 2),
        AssessmentOption(id: 'D', text: 'Decide based on what I want at the moment', points: 1),
      ],
    ),
    AssessmentQuestion(
      id: 'q8',
      category: AssessmentCategory.paymentDiscipline,
      question: 'How do you handle recurring financial payments such as EMIs or bills?',
      options: [
        AssessmentOption(id: 'A', text: 'I track them and pay before the due date', points: 4),
        AssessmentOption(id: 'B', text: 'I usually pay on time', points: 3),
        AssessmentOption(id: 'C', text: 'I sometimes need reminders', points: 2),
        AssessmentOption(id: 'D', text: 'I occasionally miss payments', points: 1),
      ],
    ),
  ];
}
