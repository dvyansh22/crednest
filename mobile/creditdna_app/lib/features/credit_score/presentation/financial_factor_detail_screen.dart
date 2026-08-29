import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../application/score_provider.dart';
import '../data/models/score_model.dart';

/// Reusable detail screen for any [FinancialFactorModel] — one file instead
/// of six near-identical screens.
class FinancialFactorDetailScreen extends ConsumerWidget {
  final String factorId;
  final FinancialFactorModel? initialFactor;

  const FinancialFactorDetailScreen({super.key, required this.factorId, this.initialFactor});

  FinancialFactorModel? _resolve(WidgetRef ref) {
    if (initialFactor != null) return initialFactor;
    final factors = ref.read(financialReportProvider).report?.financialFactors ?? const [];
    for (final f in factors) {
      if (f.id == factorId) return f;
    }
    return null;
  }

  Color _colorFor(FactorColorType type) {
    switch (type) {
      case FactorColorType.positive:
        return AppColors.green;
      case FactorColorType.moderate:
        return AppColors.gold;
      case FactorColorType.attention:
        return AppColors.orange;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factor = _resolve(ref);

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
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                  ),
                  Expanded(
                    child: Text(
                      factor?.title ?? 'Factor Details',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: factor == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          "We couldn't find details for this factor.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.subGrey),
                        ),
                      ),
                    )
                  : _DetailBody(factor: factor, color: _colorFor(factor.colorType)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final FinancialFactorModel factor;
  final Color color;
  const _DetailBody({required this.factor, required this.color});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${factor.score}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.navy, height: 1)),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text('/${factor.maxScore}', style: const TextStyle(fontSize: 15, color: AppColors.subGrey)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(factor.scoreMeaning, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
          ),
          if (factor.trendPoints.isNotEmpty) ...[
            const SizedBox(height: 22),
            _SectionCard(
              title: '${factor.title} trend',
              child: SizedBox(height: 120, child: _MiniTrendChart(points: factor.trendPoints, color: color)),
            ),
          ],
          if (factor.keyObservations.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Key observations',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final observation in factor.keyObservations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(Icons.circle, size: 5, color: AppColors.subGrey),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(observation, style: const TextStyle(fontSize: 13.5, color: AppColors.navy, height: 1.4))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (factor.suggestion.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.greenTint, borderRadius: BorderRadius.circular(16)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, color: AppColors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(factor.suggestion, style: const TextStyle(fontSize: 13, color: AppColors.navy, height: 1.4)),
                  ),
                ],
              ),
            ),
          ],
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

class _MiniTrendChart extends StatelessWidget {
  final List<double> points;
  final Color color;
  const _MiniTrendChart({required this.points, required this.color});

  @override
  Widget build(BuildContext context) {
    final spots = [for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i])];
    final minY = points.reduce((a, b) => a < b ? a : b) * 0.85;
    final maxY = points.reduce((a, b) => a > b ? a : b) * 1.1;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: color,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
