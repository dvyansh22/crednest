import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/loan_filter_model.dart';
import '../../data/models/loan_offer_model.dart';

const double kFilterMaxAmount = 1000000;
const double kFilterMaxInterestRate = 20;
const List<int> kFilterTenureOptions = [12, 18, 24, 36, 48];

Future<void> showLoanFilterSheet({
  required BuildContext context,
  required LoanFilter currentFilter,
  required List<String> availableLoanTypes,
  required ValueChanged<LoanFilter> onApply,
  required VoidCallback onReset,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => _LoanFilterSheet(
      initialFilter: currentFilter,
      availableLoanTypes: availableLoanTypes,
      onApply: onApply,
      onReset: onReset,
    ),
  );
}

class _LoanFilterSheet extends StatefulWidget {
  final LoanFilter initialFilter;
  final List<String> availableLoanTypes;
  final ValueChanged<LoanFilter> onApply;
  final VoidCallback onReset;

  const _LoanFilterSheet({
    required this.initialFilter,
    required this.availableLoanTypes,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_LoanFilterSheet> createState() => _LoanFilterSheetState();
}

class _LoanFilterSheetState extends State<_LoanFilterSheet> {
  late RangeValues _amountRange;
  late double _maxInterestRate;
  int? _tenureMonths;
  String? _loanType;
  ApprovalSpeed? _approvalSpeed;

  @override
  void initState() {
    super.initState();
    _amountRange = RangeValues(
      widget.initialFilter.minimumAmount ?? 0,
      widget.initialFilter.maximumAmount ?? kFilterMaxAmount,
    );
    _maxInterestRate = widget.initialFilter.maximumInterestRate ?? kFilterMaxInterestRate;
    _tenureMonths = widget.initialFilter.tenureMonths;
    _loanType = widget.initialFilter.loanType;
    _approvalSpeed = widget.initialFilter.approvalSpeed;
  }

  void _reset() {
    setState(() {
      _amountRange = const RangeValues(0, kFilterMaxAmount);
      _maxInterestRate = kFilterMaxInterestRate;
      _tenureMonths = null;
      _loanType = null;
      _approvalSpeed = null;
    });
    widget.onReset();
  }

  void _apply() {
    widget.onApply(
      LoanFilter(
        minimumAmount: _amountRange.start > 0 ? _amountRange.start : null,
        maximumAmount: _amountRange.end < kFilterMaxAmount ? _amountRange.end : null,
        maximumInterestRate: _maxInterestRate < kFilterMaxInterestRate ? _maxInterestRate : null,
        tenureMonths: _tenureMonths,
        loanType: _loanType,
        approvalSpeed: _approvalSpeed,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(4))),
              ),
              const SizedBox(height: 18),
              const Text('Filter Offers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
              const SizedBox(height: 22),
              _sectionTitle('Loan Amount'),
              Text(
                '₹${_amountRange.start.round()} — ₹${_amountRange.end.round()}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.subGrey),
              ),
              RangeSlider(
                values: _amountRange,
                min: 0,
                max: kFilterMaxAmount,
                divisions: 20,
                activeColor: AppColors.navy,
                inactiveColor: AppColors.divider,
                onChanged: (values) => setState(() => _amountRange = values),
              ),
              const SizedBox(height: 10),
              _sectionTitle('Maximum Interest Rate'),
              Text('${_maxInterestRate.toStringAsFixed(1)}% p.a.', style: const TextStyle(fontSize: 12.5, color: AppColors.subGrey)),
              Slider(
                value: _maxInterestRate,
                min: 5,
                max: kFilterMaxInterestRate,
                divisions: 30,
                activeColor: AppColors.navy,
                inactiveColor: AppColors.divider,
                onChanged: (value) => setState(() => _maxInterestRate = value),
              ),
              const SizedBox(height: 10),
              _sectionTitle('Tenure'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(label: 'Any', selected: _tenureMonths == null, onTap: () => setState(() => _tenureMonths = null)),
                  for (final months in kFilterTenureOptions)
                    _chip(
                      label: '$months mo',
                      selected: _tenureMonths == months,
                      onTap: () => setState(() => _tenureMonths = months),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _sectionTitle('Loan Type'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(label: 'All', selected: _loanType == null, onTap: () => setState(() => _loanType = null)),
                  for (final type in widget.availableLoanTypes)
                    _chip(label: type, selected: _loanType == type, onTap: () => setState(() => _loanType = type)),
                ],
              ),
              const SizedBox(height: 18),
              _sectionTitle('Approval Speed'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(label: 'Any', selected: _approvalSpeed == null, onTap: () => setState(() => _approvalSpeed = null)),
                  for (final speed in ApprovalSpeed.values)
                    _chip(
                      label: speed.label.replaceAll(' approval', ''),
                      selected: _approvalSpeed == speed,
                      onTap: () => setState(() => _approvalSpeed = speed),
                    ),
                ],
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _reset,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.navy,
                          side: const BorderSide(color: AppColors.cardBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Reset', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _apply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('Apply Filters', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) =>
      Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy));

  Widget _chip({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.navy),
        ),
      ),
    );
  }
}
