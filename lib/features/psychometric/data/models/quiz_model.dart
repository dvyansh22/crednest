import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

enum AssessmentCategory {
  spendingHabits,
  savingPlanning,
  financialResilience,
  borrowingAwareness,
  financialAwareness,
  decisionMaking,
  paymentDiscipline,
}

extension AssessmentCategoryX on AssessmentCategory {
  String get label {
    switch (this) {
      case AssessmentCategory.spendingHabits:
        return 'Spending Habits';
      case AssessmentCategory.savingPlanning:
        return 'Saving & Planning';
      case AssessmentCategory.financialResilience:
        return 'Financial Resilience';
      case AssessmentCategory.borrowingAwareness:
        return 'Borrowing Awareness';
      case AssessmentCategory.financialAwareness:
        return 'Financial Awareness';
      case AssessmentCategory.decisionMaking:
        return 'Decision Making';
      case AssessmentCategory.paymentDiscipline:
        return 'Payment Discipline';
    }
  }

  String get sectionLabel => label.toUpperCase();

  IconData get icon {
    switch (this) {
      case AssessmentCategory.spendingHabits:
        return Icons.account_balance_wallet_outlined;
      case AssessmentCategory.savingPlanning:
        return Icons.savings_outlined;
      case AssessmentCategory.financialResilience:
        return Icons.shield_outlined;
      case AssessmentCategory.borrowingAwareness:
        return Icons.credit_card_outlined;
      case AssessmentCategory.financialAwareness:
        return Icons.lightbulb_outline;
      case AssessmentCategory.decisionMaking:
        return Icons.balance_outlined;
      case AssessmentCategory.paymentDiscipline:
        return Icons.event_available_outlined;
    }
  }

  Color get color {
    switch (this) {
      case AssessmentCategory.spendingHabits:
      case AssessmentCategory.paymentDiscipline:
        return AppColors.green;
      case AssessmentCategory.savingPlanning:
      case AssessmentCategory.borrowingAwareness:
      case AssessmentCategory.financialAwareness:
        return AppColors.blue;
      case AssessmentCategory.financialResilience:
      case AssessmentCategory.decisionMaking:
        return AppColors.gold;
    }
  }
}

/// One selectable answer. [points] feeds the temporary prototype scoring
/// model (see [QuizRepository]) — A=4 .. D=1.
class AssessmentOption {
  final String id; // 'A', 'B', 'C', 'D'
  final String text;
  final int points;

  const AssessmentOption({required this.id, required this.text, required this.points});
}

class AssessmentQuestion {
  final String id;
  final AssessmentCategory category;
  final String question;
  final List<AssessmentOption> options;

  const AssessmentQuestion({
    required this.id,
    required this.category,
    required this.question,
    required this.options,
  });
}
