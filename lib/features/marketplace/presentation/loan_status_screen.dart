import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../application/marketplace_provider.dart';
import '../data/models/loan_application_model.dart';
import 'widgets/loan_status_stepper.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) => '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

String _formatDateTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${_formatDate(date)}, $hour:$minute';
}

String _formatAmount(double amount) {
  final rounded = amount.round().toString();
  final buffer = StringBuffer();
  final digits = rounded.split('').reversed.toList();
  for (int i = 0; i < digits.length; i++) {
    if (i == 3 || (i > 3 && (i - 3) % 2 == 0)) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '₹${buffer.toString().split('').reversed.join()}';
}

class LoanStatusScreen extends ConsumerStatefulWidget {
  const LoanStatusScreen({super.key});

  @override
  ConsumerState<LoanStatusScreen> createState() => _LoanStatusScreenState();
}

class _LoanStatusScreenState extends ConsumerState<LoanStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(loanApplicationProvider.notifier).refreshStatus());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loanApplicationProvider);
    final application = state.application;
    final offer = state.selectedOffer;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/dashboard');
                      }
                    },
                    icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                  ),
                  const Expanded(
                    child: Text(
                      'Application Status',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: application == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          "We couldn't find this application.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.subGrey),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.blue,
                      onRefresh: () => ref.read(loanApplicationProvider.notifier).refreshStatus(),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: LoanStatusStepper(status: application.status),
                            ),
                            const SizedBox(height: 16),
                            _StatusDetailCard(application: application, lenderName: offer?.lenderName),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDetailCard extends StatelessWidget {
  final LoanApplication application;
  final String? lenderName;
  const _StatusDetailCard({required this.application, required this.lenderName});

  @override
  Widget build(BuildContext context) {
    switch (application.status) {
      case LoanApplicationStatus.submitted:
        return _card(
          icon: Icons.check_circle_outline,
          color: AppColors.green,
          title: 'Application Submitted',
          child: Column(
            children: [
              _row('Application ID', application.applicationId),
              const SizedBox(height: 8),
              _row('Submitted', _formatDateTime(application.submittedAt)),
            ],
          ),
        );
      case LoanApplicationStatus.underReview:
        return _card(
          icon: Icons.hourglass_top,
          color: AppColors.blue,
          title: 'Under Review',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your application is being reviewed by the lender.',
                style: TextStyle(fontSize: 13, color: AppColors.subGrey, height: 1.4),
              ),
              SizedBox(height: 8),
              Text(
                'Estimated response time: 1–2 business days',
                style: TextStyle(fontSize: 12, color: AppColors.subGrey),
              ),
            ],
          ),
        );
      case LoanApplicationStatus.approved:
        return _card(
          icon: Icons.verified_outlined,
          color: AppColors.green,
          title: 'Approved',
          child: Column(
            children: [
              if (application.approvedAmount != null) _row('Approved Amount', _formatAmount(application.approvedAmount!)),
              if (application.finalInterestRate != null) ...[
                const SizedBox(height: 8),
                _row('Final Interest Rate', '${application.finalInterestRate!.toStringAsFixed(1)}% p.a.'),
              ],
              if (application.finalEmi != null) ...[
                const SizedBox(height: 8),
                _row('Final EMI', _formatAmount(application.finalEmi!)),
              ],
              if (application.finalTenureMonths != null) ...[
                const SizedBox(height: 8),
                _row('Tenure', '${application.finalTenureMonths} Months'),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: () => context.push('/offers/${application.offerId}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: AppColors.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('View Loan Details', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      case LoanApplicationStatus.disbursed:
        return _card(
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.green,
          title: 'Disbursed',
          child: Column(
            children: [
              if (application.approvedAmount != null) _row('Amount', _formatAmount(application.approvedAmount!)),
              if (application.disbursedAt != null) ...[
                const SizedBox(height: 8),
                _row('Disbursement Date', _formatDate(application.disbursedAt!)),
              ],
              if (application.maskedAccountReference != null) ...[
                const SizedBox(height: 8),
                _row('Account', application.maskedAccountReference!),
              ],
            ],
          ),
        );
      case LoanApplicationStatus.rejected:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.cancel_outlined, color: AppColors.errorRed, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Application Not Approved', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'The lender was unable to approve this application at this time.',
                style: TextStyle(fontSize: 13, color: AppColors.subGrey, height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.go('/offers'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Explore Other Offers', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _row(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.subGrey))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy)),
      ],
    );
  }

  Widget _card({required IconData icon, required Color color, required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
