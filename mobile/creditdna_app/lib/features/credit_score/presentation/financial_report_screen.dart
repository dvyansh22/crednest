import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../dashboard/presentation/widgets/dashboard_bottom_nav.dart';
import '../application/score_provider.dart';
import '../data/models/score_model.dart';
import 'widgets/credit_dna_trend_chart.dart';
import 'widgets/financial_factor_row.dart';
import 'widgets/report_action_card.dart';
import 'widgets/report_score_gauge.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) => '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

class FinancialReportScreen extends ConsumerStatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  ConsumerState<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends ConsumerState<FinancialReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(financialReportProvider.notifier).loadReport());
  }

  void _openMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh, color: AppColors.navy),
              title: const Text('Refresh report'),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(financialReportProvider.notifier).loadReport();
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.navy),
              title: const Text('Privacy information'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/consent');
              },
            ),
            ListTile(
              leading: const Icon(Icons.hub_outlined, color: AppColors.navy),
              title: const Text('Data sources'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/consent');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleDownload() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF export is coming soon.')),
    );
  }

  void _showFactorsInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tap any factor below to see its full breakdown.')),
    );
  }

  void _openFactorDetail(FinancialFactorModel factor) {
    if (factor.dataAvailability == FactorDataAvailability.notConnected) {
      context.push(factor.connectRoute);
      return;
    }
    context.push('/credit-dna-report/factor/${factor.id}', extra: factor);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financialReportProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const DashboardBottomNav(currentIndex: 1),
      body: SafeArea(
        child: Column(
          children: [
            _Header(onDownload: _handleDownload, onMore: _openMoreOptions),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(FinancialReportState state) {
    switch (state.status) {
      case FinancialReportStatus.loading:
        return const _ReportSkeleton();
      case FinancialReportStatus.error:
        return _ReportError(
          message: state.errorMessage ?? 'Unable to load your financial report. Please try again.',
          onRetry: () => ref.read(financialReportProvider.notifier).loadReport(),
        );
      case FinancialReportStatus.loaded:
        final report = state.report!;
        return RefreshIndicator(
          color: AppColors.blue,
          onRefresh: () => ref.read(financialReportProvider.notifier).loadReport(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Updated ${_formatDate(report.updatedAt)}', style: const TextStyle(fontSize: 12, color: AppColors.subGrey)),
                const SizedBox(height: 18),
                if (report.hasBankData) ...[
                  _ScoreOverviewCard(report: report),
                  const SizedBox(height: 18),
                  _TrendCard(report: report),
                ] else
                  const _NoBankDataCard(),
                const SizedBox(height: 26),
                Row(
                  children: [
                    const Text('Financial Factors', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    const Spacer(),
                    GestureDetector(
                      onTap: _showFactorsInfo,
                      child: const Text('See details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.blue)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < report.financialFactors.length; i++) ...[
                        FinancialFactorRow(factor: report.financialFactors[i], onTap: () => _openFactorDetail(report.financialFactors[i])),
                        if (i != report.financialFactors.length - 1) const Divider(height: 1, color: AppColors.divider),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const Text('What You Can Do Next', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 12),
                _RecommendationsRow(recommendations: report.recommendations),
              ],
            ),
          ),
        );
    }
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onDownload;
  final VoidCallback onMore;
  const _Header({required this.onDownload, required this.onMore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
            icon: const Icon(Icons.arrow_back, color: AppColors.navy),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Financial Report', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 3),
                  const Text(
                    'A deeper breakdown of your financial health',
                    style: TextStyle(fontSize: 12.5, color: AppColors.subGrey),
                  ),
                ],
              ),
            ),
          ),
          IconButton(onPressed: onDownload, icon: const Icon(Icons.download_outlined, color: AppColors.navy)),
          IconButton(onPressed: onMore, icon: const Icon(Icons.more_vert, color: AppColors.navy)),
        ],
      ),
    );
  }
}

class _ScoreOverviewCard extends StatelessWidget {
  final FinancialReportModel report;
  const _ScoreOverviewCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gauge = ReportScoreGauge(progress: report.creditDnaScore / report.maxScore, percentile: report.percentile);
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('CreditDNA Score', style: TextStyle(fontSize: 13, color: AppColors.subGrey)),
                  const SizedBox(width: 5),
                  Icon(Icons.info_outline, size: 14, color: AppColors.subGrey.withValues(alpha: 0.8)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${report.creditDnaScore}', style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: AppColors.navy, height: 1)),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text('/ ${report.maxScore}', style: const TextStyle(fontSize: 14, color: AppColors.subGrey)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(report.scoreStatus, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.green)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_upward, size: 13, color: AppColors.green),
                  const SizedBox(width: 3),
                  Text(
                    '${report.scoreChange} points in the last 3 months',
                    style: const TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          );

          if (constraints.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 20), Center(child: gauge)],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: info),
              const SizedBox(width: 12),
              gauge,
            ],
          );
        },
      ),
    );
  }
}

class _TrendCard extends StatefulWidget {
  final FinancialReportModel report;
  const _TrendCard({required this.report});

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  static const _periods = ['1 Month', '3 Months', '6 Months', '1 Year'];
  String _selectedPeriod = '3 Months';

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                const Text('CreditDNA Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const Spacer(),
                PopupMenuButton<String>(
                  initialValue: _selectedPeriod,
                  onSelected: (value) => setState(() => _selectedPeriod = value),
                  itemBuilder: (context) => _periods.map((p) => PopupMenuItem(value: p, child: Text(p))).toList(),
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
          ),
          const SizedBox(height: 6),
          CreditDnaTrendChart(trend: report.trend),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, size: 16, color: AppColors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your score has improved by ${report.scoreChange} points in the last 3 months.',
                      style: const TextStyle(fontSize: 12, color: AppColors.navy, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoBankDataCard extends StatelessWidget {
  const _NoBankDataCard();

  @override
  Widget build(BuildContext context) {
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
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.blueTint, shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_outlined, color: AppColors.blue, size: 20),
          ),
          const SizedBox(height: 14),
          const Text(
            'Connect your bank account to unlock income and cash flow insights.',
            style: TextStyle(fontSize: 14, color: AppColors.navy, fontWeight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: () => context.push('/connect-bank'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Connect Bank', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationsRow extends StatelessWidget {
  final List<RecommendationModel> recommendations;
  const _RecommendationsRow({required this.recommendations});

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          for (final r in recommendations)
            ReportActionCard(recommendation: r, onTap: () => context.push(r.route)),
        ];

        if (constraints.maxWidth < 360 || cards.length == 1) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i != cards.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ReportSkeleton extends StatelessWidget {
  const _ReportSkeleton();

  Widget _block({double height = 100, double radius = 20}) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: AppColors.cardBorder.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(radius)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        children: [
          _block(height: 190),
          _block(height: 210),
          _block(height: 200),
          _block(height: 90),
        ],
      ),
    );
  }
}

class _ReportError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ReportError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.subGrey, size: 34),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.subGrey, height: 1.4)),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
