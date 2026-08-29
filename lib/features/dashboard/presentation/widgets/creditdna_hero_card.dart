import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/dashboard_models.dart';
import 'creditdna_gauge.dart';

class CreditDnaHeroCard extends StatelessWidget {
  final CreditDnaScoreData data;

  const CreditDnaHeroCard({super.key, required this.data});

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
          Row(
            children: [
              const Text(
                'Your CreditDNA',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _showInfo(context),
                child: Icon(Icons.info_outline, size: 16, color: AppColors.subGrey.withValues(alpha: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (data.isAvailable) ..._buildAvailableState() else ..._buildBuildingState(context),
          if (data.isAvailable) ...[
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 16),
            const _SignalJourneyRow(),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildAvailableState() {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data.score}',
                  style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: AppColors.green, height: 1),
                ),
                const SizedBox(height: 2),
                Text('out of ${data.maxScore}', style: const TextStyle(fontSize: 13, color: AppColors.subGrey)),
                const SizedBox(height: 10),
                _StatusPill(status: data.status),
                const SizedBox(height: 12),
                Text(
                  data.insightText,
                  style: const TextStyle(fontSize: 13, color: AppColors.subGrey, height: 1.4),
                ),
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  return GestureDetector(
                    onTap: () => context.push('/credit-dna-report'),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View full report',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.blue),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 14, color: AppColors.blue),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: CreditDnaGauge(progress: data.score / data.maxScore),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildBuildingState(BuildContext context) {
    return [
      const Text(
        'Your CreditDNA is taking shape',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy),
      ),
      const SizedBox(height: 8),
      const Text(
        'Connect your financial data to unlock a more complete financial profile.',
        style: TextStyle(fontSize: 13.5, color: AppColors.subGrey, height: 1.4),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          const Text('Profile confidence', style: TextStyle(fontSize: 12.5, color: AppColors.subGrey, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(
            '${(data.profileConfidence * 100).round()}%',
            style: const TextStyle(fontSize: 12.5, color: AppColors.navy, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LinearProgressIndicator(
          value: data.profileConfidence,
          minHeight: 8,
          backgroundColor: AppColors.divider,
          valueColor: const AlwaysStoppedAnimation(AppColors.gold),
        ),
      ),
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: () => context.push('/connect-bank'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Continue Building', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
              SizedBox(width: 6),
              Icon(Icons.arrow_forward, size: 16),
            ],
          ),
        ),
      ),
    ];
  }

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('What is CreditDNA?', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
        content: const Text(
          'Your CreditDNA score is built from consented signals like income, cash flow, '
          'consistency, and data confidence — a broader picture of your financial identity '
          'beyond a traditional credit score.',
          style: TextStyle(color: AppColors.subGrey, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final CreditDnaStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      CreditDnaStatus.excellent => AppColors.green,
      CreditDnaStatus.good => AppColors.green,
      CreditDnaStatus.building => AppColors.gold,
      CreditDnaStatus.needsAttention => AppColors.errorRed,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _SignalStep {
  final String label;
  final IconData icon;
  final Color color;
  const _SignalStep(this.label, this.icon, this.color);
}

const _signalSteps = [
  _SignalStep('Income', Icons.account_balance_wallet_outlined, AppColors.blue),
  _SignalStep('Cash Flow', Icons.show_chart, AppColors.teal),
  _SignalStep('Consistency', Icons.verified_user_outlined, AppColors.green),
  _SignalStep('Data\nConfidence', Icons.workspace_premium_outlined, AppColors.gold),
  _SignalStep('Score', Icons.fingerprint, AppColors.green),
];

class _SignalJourneyRow extends StatelessWidget {
  const _SignalJourneyRow();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (int i = 0; i < _signalSteps.length; i++) ...[
              _SignalDot(step: _signalSteps[i]),
              if (i != _signalSteps.length - 1)
                Expanded(
                  child: Container(height: 1.5, color: AppColors.divider, margin: const EdgeInsets.symmetric(horizontal: 2)),
                ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final step in _signalSteps)
              Expanded(
                child: Text(
                  step.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9.5, color: AppColors.subGrey, fontWeight: FontWeight.w600, height: 1.2),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SignalDot extends StatelessWidget {
  final _SignalStep step;
  const _SignalDot({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: step.color.withValues(alpha: 0.14), shape: BoxShape.circle),
      child: Icon(step.icon, size: 14, color: step.color),
    );
  }
}
