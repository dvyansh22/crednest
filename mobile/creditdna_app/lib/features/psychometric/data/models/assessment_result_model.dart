import 'quiz_model.dart';

enum HabitStrength { strong, good, average, developing }

extension HabitStrengthX on HabitStrength {
  String get label {
    switch (this) {
      case HabitStrength.strong:
        return 'Strong';
      case HabitStrength.good:
        return 'Good';
      case HabitStrength.average:
        return 'Average';
      case HabitStrength.developing:
        return 'Developing';
    }
  }
}

/// One category's result — [averagePoints] is on the 1..4 scale from the
/// temporary scoring model, [progress] is that normalized to 0..1 for the
/// summary bar.
class CategoryScoreResult {
  final AssessmentCategory category;
  final double averagePoints;
  final double progress;
  final HabitStrength strength;

  const CategoryScoreResult({
    required this.category,
    required this.averagePoints,
    required this.progress,
    required this.strength,
  });
}

class AssessmentResult {
  final List<CategoryScoreResult> categoryScores;
  final DateTime completedAt;

  const AssessmentResult({required this.categoryScores, required this.completedAt});

  /// Whether the overall result leans positive — drives the closing insight
  /// message. Simple average-based heuristic, not a validated scoring model.
  bool get isOverallPositive {
    if (categoryScores.isEmpty) return true;
    final avg = categoryScores.map((c) => c.averagePoints).reduce((a, b) => a + b) / categoryScores.length;
    return avg >= 2.5;
  }
}
