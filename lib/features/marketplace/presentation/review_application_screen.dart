import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../dashboard/application/dashboard_provider.dart';
import '../../dashboard/data/models/dashboard_models.dart';
import '../../profile/data/models/user_profile_model.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../application/marketplace_provider.dart';
import 'widgets/application_step_indicator.dart';

class ReviewApplicationScreen extends ConsumerWidget {
  const ReviewApplicationScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offer = ref.watch(loanApplicationProvider).selectedOffer;
    final profileState = ref.watch(userProfileProvider);
    final profile = profileState.profile;
    final creditDna = ref.watch(dashboardProvider).data?.creditDna;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 4),
              child: Row(
                children: [
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back, color: AppColors.navy)),
                  const Expanded(
                    child: Text(
                      'Review Application',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: const ApplicationStepIndicator(currentStep: 0),
            ),
            Expanded(
              child: offer == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          "We couldn't find the selected offer. Please go back and select a loan offer again.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.subGrey),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionCard(
                            title: 'Loan summary',
                            child: Column(
                              children: [
                                _row('Lender', offer.lenderName),
                                _row('Loan Type', offer.loanType),
                                _row('Loan Amount', _formatAmount(offer.loanAmount)),
                                _row('Interest Rate', '${offer.interestRatePercent.toStringAsFixed(1)}% p.a.'),
                                _row('Tenure', '${offer.tenureMonths} Months'),
                                _row('Estimated EMI', _formatAmount(offer.emi), isLast: true),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (profile == null)
                            _MissingProfileCard(onCompleteProfile: () => context.push('/profile-setup'))
                          else
                            _SectionCard(
                              title: 'Your profile information',
                              child: Column(
                                children: [
                                  _row('Name', profile.fullName),
                                  _row('Phone', profile.phoneNumber),
                                  _row('Email', profile.email),
                                  _row('User Type', profile.userType.label),
                                  _row('Employment Type', profile.employmentType.label),
                                  _row('Income Category', profile.incomeCategory.label, isLast: true),
                                ],
                              ),
                            ),
                          const SizedBox(height: 14),
                          if (creditDna != null && creditDna.isAvailable)
                            _SectionCard(
                              title: 'CreditDNA Score',
                              child: Row(
                                children: [
                                  Text('${creditDna.score}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.green)),
                                  Text(' / ${creditDna.maxScore}', style: const TextStyle(fontSize: 13, color: AppColors.subGrey)),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(color: AppColors.greenTint, borderRadius: BorderRadius.circular(20)),
                                    child: Text(
                                      creditDna.status.label,
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.green),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            if (offer != null && profile != null)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.divider))),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => context.push('/offers/apply/consent'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('Continue', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.subGrey))),
          Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.navy)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _MissingProfileCard extends StatelessWidget {
  final VoidCallback onCompleteProfile;
  const _MissingProfileCard({required this.onCompleteProfile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.goldTint, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.gold, size: 18),
              SizedBox(width: 8),
              Text('Profile information missing', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'We need your profile details to continue with this application.',
            style: TextStyle(fontSize: 12.5, color: AppColors.subGrey, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: onCompleteProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Complete Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
