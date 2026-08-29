import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../consent/application/consent_provider.dart';
import '../../consent/data/models/consent_model.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../application/marketplace_provider.dart';
import 'widgets/application_step_indicator.dart';

/// Loan-specific framing of why each consent is needed — the underlying
/// consent record (status, expiry) still comes entirely from the Consent
/// Center's own data; this only relabels the purpose for this context.
const Map<String, String> _loanPurposeLabels = {
  'financial-data': 'Creditworthiness Assessment',
  'identity-verification': 'Identity and KYC Verification',
  'gst-data': 'Business Income Verification',
  'psychometric-assessment': 'Additional Behavioral Assessment',
};

class ConfirmLoanConsentScreen extends ConsumerStatefulWidget {
  const ConfirmLoanConsentScreen({super.key});

  @override
  ConsumerState<ConfirmLoanConsentScreen> createState() => _ConfirmLoanConsentScreenState();
}

class _ConfirmLoanConsentScreenState extends ConsumerState<ConfirmLoanConsentScreen> {
  bool _authorized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(consentProvider.notifier).loadConsents());
  }

  Future<void> _handleSubmit() async {
    final success = await ref.read(loanApplicationProvider.notifier).submit();
    if (!mounted) return;
    if (success) {
      context.push('/offers/apply/submitted');
    } else {
      final message = ref.read(loanApplicationProvider).errorMessage ?? 'Something went wrong. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final consentState = ref.watch(consentProvider);
    final applicationState = ref.watch(loanApplicationProvider);
    final userType = ref.watch(userProfileProvider).profile?.userType;
    final relevantIds = ref.read(loanApplicationProvider.notifier).relevantConsentIds(userType);
    final isSubmitting = applicationState.submitStatus == LoanApplicationSubmitStatus.submitting;

    final relevantConsents = <ConsentModel>[
      for (final id in relevantIds)
        ...consentState.consents.where((c) => c.id == id),
    ];
    final allActive = relevantConsents.length == relevantIds.length &&
        relevantConsents.every((c) => c.status == ConsentStatus.active);
    final canSubmit = allActive && _authorized && !isSubmitting;

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
                      'Confirm Consent',
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
              child: const ApplicationStepIndicator(currentStep: 1),
            ),
            Expanded(
              child: consentState.status == ConsentLoadStatus.loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'This application uses the data below. Review what will be shared before submitting.',
                            style: TextStyle(fontSize: 13, color: AppColors.subGrey, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          for (final id in relevantIds) ...[
                            _ConsentRow(
                              consent: consentState.consents.where((c) => c.id == id).isEmpty
                                  ? null
                                  : consentState.consents.firstWhere((c) => c.id == id),
                              purposeOverride: _loanPurposeLabels[id] ?? '',
                              onProvideConsent: (route) => context.push(route),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.divider))),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _authorized = !_authorized),
                      borderRadius: BorderRadius.circular(10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _authorized,
                            onChanged: (value) => setState(() => _authorized = value ?? false),
                            activeColor: AppColors.navy,
                          ),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                'I understand and authorize the use of the selected data for this loan application.',
                                style: TextStyle(fontSize: 12.5, color: AppColors.navy, height: 1.35),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: canSubmit ? _handleSubmit : null,
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
                            : const Text('Submit Application', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
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

class _ConsentRow extends StatelessWidget {
  final ConsentModel? consent;
  final String purposeOverride;
  final ValueChanged<String> onProvideConsent;

  const _ConsentRow({required this.consent, required this.purposeOverride, required this.onProvideConsent});

  @override
  Widget build(BuildContext context) {
    final c = consent;
    final isActive = c != null && c.status == ConsentStatus.active;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: (c?.accentColor ?? AppColors.subGrey).withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(c?.icon ?? Icons.shield_outlined, size: 17, color: c?.accentColor ?? AppColors.subGrey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c?.title ?? 'Consent', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 2),
                Text(purposeOverride, style: const TextStyle(fontSize: 11.5, color: AppColors.subGrey)),
                const SizedBox(height: 6),
                if (isActive)
                  Text(
                    'Active • Expires in ${c.daysUntilExpiry ?? 0} days',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.green),
                  )
                else
                  const Text('Consent Required', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.errorRed)),
              ],
            ),
          ),
          if (!isActive && c != null)
            TextButton(
              onPressed: () => onProvideConsent(c.actionRoute),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
              child: const Text('Provide Consent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.blue)),
            ),
        ],
      ),
    );
  }
}
