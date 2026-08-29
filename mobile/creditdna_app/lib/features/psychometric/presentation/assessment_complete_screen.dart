import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';

class AssessmentCompleteScreen extends StatefulWidget {
  const AssessmentCompleteScreen({super.key});

  @override
  State<AssessmentCompleteScreen> createState() => _AssessmentCompleteScreenState();
}

class _AssessmentCompleteScreenState extends State<AssessmentCompleteScreen> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
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
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(color: AppColors.greenTint, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle, color: AppColors.green, size: 52),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Assessment Complete!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              const SizedBox(height: 10),
              const Text(
                'Thank you for completing the assessment.\nYour responses have been saved.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, color: AppColors.subGrey, height: 1.45),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.greenTint, borderRadius: BorderRadius.circular(16)),
                child: const Row(
                  children: [
                    Icon(Icons.insights_outlined, color: AppColors.green, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "We're analyzing your responses to strengthen your financial profile.",
                        style: TextStyle(fontSize: 13, color: AppColors.navy, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => context.push('/psychometric-quiz/results'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('View My Insights', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text('Go to Home', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.subGrey)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
