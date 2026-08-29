import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';

class GreetingHeader extends StatelessWidget {
  /// Null when no name is available yet — renders "Hello 👋" rather than
  /// ever showing a literal "null" or a hardcoded placeholder name.
  final String? firstName;

  const GreetingHeader({super.key, required this.firstName});

  @override
  Widget build(BuildContext context) {
    final greeting = firstName == null || firstName!.isEmpty ? 'Hello 👋' : 'Hello, $firstName 👋';
    final initial = (firstName == null || firstName!.isEmpty) ? null : firstName![0].toUpperCase();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              const SizedBox(height: 3),
              const Text(
                "Here's your financial snapshot",
                style: TextStyle(fontSize: 13.5, color: AppColors.subGrey),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.blueTint,
            child: initial == null
                ? const Icon(Icons.person_outline, color: AppColors.blue)
                : Text(initial, style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ),
      ],
    );
  }
}
