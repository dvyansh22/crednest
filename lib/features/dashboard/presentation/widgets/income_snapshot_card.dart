import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/dashboard_models.dart';

class IncomeSnapshotCard extends StatefulWidget {
  final IncomeSnapshotData data;

  const IncomeSnapshotCard({super.key, required this.data});

  @override
  State<IncomeSnapshotCard> createState() => _IncomeSnapshotCardState();
}

class _IncomeSnapshotCardState extends State<IncomeSnapshotCard> {
  static const _periods = ['This month', 'Last 3 months', 'Last 6 months'];
  String _selectedPeriod = _periods.first;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final formattedAmount = '₹${_formatAmount(data.amount)}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Income snapshot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
              const Spacer(),
              PopupMenuButton<String>(
                initialValue: _selectedPeriod,
                onSelected: (value) => setState(() => _selectedPeriod = value),
                itemBuilder: (context) =>
                    _periods.map((p) => PopupMenuItem(value: p, child: Text(p))).toList(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_selectedPeriod, style: const TextStyle(fontSize: 12.5, color: AppColors.subGrey, fontWeight: FontWeight.w600)),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.subGrey),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.label, style: const TextStyle(fontSize: 12.5, color: AppColors.subGrey)),
                    const SizedBox(height: 6),
                    Text(
                      formattedAmount,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.navy),
                    ),
                    if (data.growthPercent != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.arrow_upward, size: 13, color: AppColors.green),
                          const SizedBox(width: 3),
                          Text(
                            '${data.growthPercent!.toStringAsFixed(0)}% from last month',
                            style: const TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                    if (data.extraInfo != null) ...[
                      const SizedBox(height: 4),
                      Text(data.extraInfo!, style: const TextStyle(fontSize: 11.5, color: AppColors.subGrey)),
                    ],
                  ],
                ),
              ),
              Expanded(
                flex: 5,
                child: SizedBox(height: 72, child: _IncomeTrendChart(points: data.trendPoints)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.bar_chart_rounded, size: 16, color: AppColors.green),
                const SizedBox(width: 8),
                Text(data.stabilityLabel, style: const TextStyle(fontSize: 13, color: AppColors.navy, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(data.stabilityStatus, style: const TextStyle(fontSize: 13, color: AppColors.green, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatAmount(double amount) {
    final rounded = amount.round().toString();
    final buffer = StringBuffer();
    final digits = rounded.split('').reversed.toList();
    for (int i = 0; i < digits.length; i++) {
      final posFromEnd = i;
      if (posFromEnd == 3 || (posFromEnd > 3 && (posFromEnd - 3) % 2 == 0)) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString().split('').reversed.join();
  }
}

class _IncomeTrendChart extends StatelessWidget {
  final List<double> points;
  const _IncomeTrendChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final spots = [for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i])];
    final minY = points.reduce((a, b) => a < b ? a : b) * 0.9;
    final maxY = points.reduce((a, b) => a > b ? a : b) * 1.05;

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
            curveSmoothness: 0.35,
            color: AppColors.green,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.green.withValues(alpha: 0.22), AppColors.green.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
