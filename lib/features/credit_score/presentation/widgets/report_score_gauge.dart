import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Nearly-full circular gauge for the report overview — a green arc
/// proportional to the score, with the percentile comparison sitting in
/// the gap at the bottom. Deliberately simpler than the dashboard's
/// multi-signal gauge: this one is a single, calm accent color.
class ReportScoreGauge extends StatelessWidget {
  final double progress; // 0..1, score / maxScore
  final int percentile;
  final double size;

  const ReportScoreGauge({super.key, required this.progress, required this.percentile, this.size = 168});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _GaugePainter(progress: progress.clamp(0.0, 1.0)),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: size * 0.06),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('You are ahead of', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.subGrey)),
                const SizedBox(height: 2),
                Text('$percentile%', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.green)),
                const SizedBox(height: 2),
                const Text('of CredNest users', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.subGrey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  _GaugePainter({required this.progress});

  static const double _startAngleDeg = 105;
  static const double _sweepAngleDeg = 330;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.075;
    final diameter = size.width - strokeWidth;
    final rect = Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, diameter, diameter);

    final startAngle = _startAngleDeg * pi / 180;
    final sweepAngle = _sweepAngleDeg * pi / 180;

    final trackPaint = Paint()
      ..color = AppColors.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);

    final progressSweep = sweepAngle * progress;
    if (progressSweep > 0) {
      final fgPaint = Paint()
        ..color = AppColors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, progressSweep, false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => oldDelegate.progress != progress;
}
