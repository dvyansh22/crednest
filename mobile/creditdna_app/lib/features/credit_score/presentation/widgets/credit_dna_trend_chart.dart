import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/score_model.dart';

class CreditDnaTrendChart extends StatelessWidget {
  final List<MonthlyScoreModel> trend;

  const CreditDnaTrendChart({super.key, required this.trend});

  @override
  Widget build(BuildContext context) {
    final scores = trend.map((t) => t.score.toDouble()).toList();
    final minScore = scores.reduce((a, b) => a < b ? a : b);
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final minY = ((minScore - 30) / 50).floor() * 50.0;
    final maxY = ((maxScore + 40) / 50).ceil() * 50.0;
    final spots = [for (int i = 0; i < trend.length; i++) FlSpot(i.toDouble(), scores[i])];

    final barData = LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: AppColors.green,
      barWidth: 2.5,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) {
          final isLast = index == spots.length - 1;
          return FlDotCirclePainter(
            radius: isLast ? 5 : 3,
            color: AppColors.green,
            strokeWidth: isLast ? 3 : 0,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.green.withValues(alpha: 0.16), AppColors.green.withValues(alpha: 0.0)],
        ),
      ),
    );

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 3,
            getDrawingHorizontalLine: (value) => const FlLine(color: AppColors.divider, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: (maxY - minY) / 3,
                getTitlesWidget: (value, meta) =>
                    Text(value.round().toString(), style: const TextStyle(fontSize: 10, color: AppColors.subGrey)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= trend.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(trend[index].month, style: const TextStyle(fontSize: 11, color: AppColors.subGrey)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [barData],
          lineTouchData: LineTouchData(
            enabled: false,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => Colors.transparent,
              tooltipPadding: EdgeInsets.zero,
              tooltipMargin: 10,
              getTooltipItems: (touchedSpots) => touchedSpots
                  .map(
                    (spot) => LineTooltipItem(
                      spot.y.round().toString(),
                      const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                  )
                  .toList(),
            ),
          ),
          showingTooltipIndicators: [
            for (int i = 0; i < spots.length; i++) ShowingTooltipIndicators([LineBarSpot(barData, 0, spots[i])]),
          ],
        ),
      ),
    );
  }
}
