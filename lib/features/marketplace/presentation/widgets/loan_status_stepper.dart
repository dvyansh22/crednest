import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/loan_application_model.dart';

enum _StepVisualState { completed, active, pending, rejected }

const List<LoanApplicationStatus> _progression = [
  LoanApplicationStatus.submitted,
  LoanApplicationStatus.underReview,
  LoanApplicationStatus.approved,
  LoanApplicationStatus.disbursed,
];

/// Renders the status progression purely from [status] — the steps and
/// their completed/active/pending state are derived, never hardcoded into
/// a fixed visual sequence independent of the actual application.
class LoanStatusStepper extends StatelessWidget {
  final LoanApplicationStatus status;

  const LoanStatusStepper({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == LoanApplicationStatus.rejected) {
      return Column(
        children: [
          _StepRow(label: LoanApplicationStatus.submitted.label, state: _StepVisualState.completed, isLast: false),
          _StepRow(label: LoanApplicationStatus.underReview.label, state: _StepVisualState.completed, isLast: false),
          _StepRow(label: LoanApplicationStatus.rejected.label, state: _StepVisualState.rejected, isLast: true),
        ],
      );
    }

    final currentIndex = _progression.indexOf(status);
    return Column(
      children: [
        for (int i = 0; i < _progression.length; i++)
          _StepRow(
            label: _progression[i].label,
            state: i < currentIndex
                ? _StepVisualState.completed
                : i == currentIndex
                    ? _StepVisualState.active
                    : _StepVisualState.pending,
            isLast: i == _progression.length - 1,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final _StepVisualState state;
  final bool isLast;

  const _StepRow({required this.label, required this.state, required this.isLast});

  Color get _color {
    switch (state) {
      case _StepVisualState.completed:
        return AppColors.green;
      case _StepVisualState.active:
        return AppColors.blue;
      case _StepVisualState.pending:
        return AppColors.subGrey;
      case _StepVisualState.rejected:
        return AppColors.errorRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: state == _StepVisualState.pending ? Colors.white : _color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: _color, width: 1.6),
                ),
                child: Icon(
                  state == _StepVisualState.completed
                      ? Icons.check
                      : state == _StepVisualState.rejected
                          ? Icons.close
                          : Icons.circle,
                  size: state == _StepVisualState.active || state == _StepVisualState.pending ? 9 : 14,
                  color: _color,
                ),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: state == _StepVisualState.completed ? AppColors.green : AppColors.divider)),
            ],
          ),
          const SizedBox(width: 14),
          Padding(
            padding: const EdgeInsets.only(bottom: 22, top: 3),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: state == _StepVisualState.active ? FontWeight.w700 : FontWeight.w600,
                color: state == _StepVisualState.pending ? AppColors.subGrey : AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
