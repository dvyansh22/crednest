import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Semi-circular CreditDNA score gauge: a blue-to-green-to-gold arc
/// proportional to the score, with a subtle fingerprint motif behind it —
/// a quiet nod to "this score is built from many signals," not a literal
/// biometric icon.
class CreditDnaGauge extends StatelessWidget {
  final double progress; // 0..1
  final double size;

  const CreditDnaGauge({super.key, required this.progress, this.size = 132});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.72,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: -size * 0.06,
            child: Icon(
              Icons.fingerprint,
              size: size * 0.5,
              color: AppColors.subGrey.withValues(alpha: 0.12),
            ),
          ),
          CustomPaint(
            size: Size(size, size * 0.62),
            painter: _GaugePainter(progress: progress.clamp(0.0, 1.0)),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;

  _GaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.1;
    final diameter = size.width - strokeWidth;
    final rect = Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, diameter, diameter);

    final trackPaint = Paint()
      ..color = AppColors.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, pi, pi, false, trackPaint);

    final sweep = pi * progress;
    if (sweep > 0) {
      final gradient = const SweepGradient(
        startAngle: pi,
        endAngle: pi * 2,
        colors: [AppColors.blue, AppColors.teal, AppColors.green, AppColors.gold],
        stops: [0.0, 0.45, 0.8, 1.0],
      );
      final fgPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, pi, sweep, false, fgPaint);

      final radius = diameter / 2;
      final center = rect.center;
      final endAngle = pi + sweep;
      final dotCenter = Offset(
        center.dx + radius * cos(endAngle),
        center.dy + radius * sin(endAngle),
      );
      canvas.drawCircle(dotCenter, strokeWidth * 0.46, Paint()..color = Colors.white);
      canvas.drawCircle(
        dotCenter,
        strokeWidth * 0.46,
        Paint()
          ..color = AppColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => oldDelegate.progress != progress;
}
