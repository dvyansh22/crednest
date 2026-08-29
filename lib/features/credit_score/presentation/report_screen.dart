import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Destination for "View full report" on the CreditDNA hero card.
/// Placeholder until the full report experience is built — kept polished
/// and on-brand rather than a bare stub so it doesn't feel like a dead end.
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text('CreditDNA Report', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(color: AppColors.blueTint, shape: BoxShape.circle),
                child: const Icon(Icons.insights_outlined, color: AppColors.blue, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'Your full report is on its way',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              const SizedBox(height: 8),
              const Text(
                "We're building a detailed breakdown of every signal behind your CreditDNA score.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppColors.subGrey, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
