import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../application/marketplace_provider.dart';

class ApplicationSubmittedScreen extends ConsumerStatefulWidget {
  const ApplicationSubmittedScreen({super.key});

  @override
  ConsumerState<ApplicationSubmittedScreen> createState() => _ApplicationSubmittedScreenState();
}

class _ApplicationSubmittedScreenState extends ConsumerState<ApplicationSubmittedScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loanApplicationProvider);
    final application = state.application;
    final offer = state.selectedOffer;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              FadeTransition(
                opacity: _opacity,
                child: ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(color: AppColors.greenTint, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle, color: AppColors.green, size: 50),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'Application Submitted',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your application has been sent successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.subGrey),
              ),
              const SizedBox(height: 24),
              if (application != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      _row('Application ID', application.applicationId),
                      if (offer != null) ...[
                        const SizedBox(height: 10),
                        _row('Lender', offer.lenderName),
                      ],
                      const SizedBox(height: 10),
                      _row('Requested Amount', _formatAmount(application.requestedAmount)),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.blueTint, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('What happens next', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    SizedBox(height: 10),
                    _NextStepItem(number: 1, label: 'Application Submitted'),
                    _NextStepItem(number: 2, label: 'Under Review'),
                    _NextStepItem(number: 3, label: 'Decision'),
                    _NextStepItem(number: 4, label: 'Disbursement', isLast: true),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => context.push('/loan-status'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Track Application', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/offers'),
                child: const Text('Back to Loans', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.subGrey)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.subGrey))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy)),
      ],
    );
  }
}

class _NextStepItem extends StatelessWidget {
  final int number;
  final String label;
  final bool isLast;
  const _NextStepItem({required this.number, required this.label, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Center(
              child: Text('$number', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.blue)),
            ),
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.navy, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
