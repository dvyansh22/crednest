import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../../core/constants/app_colors.dart';
import '../../consent/application/consent_provider.dart';
import '../../consent/data/models/consent_model.dart';
import '../../consent/presentation/widgets/consent_item_card.dart';
import '../../consent/presentation/widgets/consent_summary_card.dart';
import '../../consent/presentation/widgets/revoke_consent_dialog.dart';

class ConnectBankScreen extends ConsumerStatefulWidget {
  const ConnectBankScreen({super.key});

  @override
  ConsumerState<ConnectBankScreen> createState() => _ConnectBankScreenState();
}

class _ConnectBankScreenState extends ConsumerState<ConnectBankScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(consentProvider.notifier).loadConsents());
  }

  Future<void> _handleAction(ConsentModel consent) async {
    if (consent.id == 'financial-data' && consent.status != ConsentStatus.active) {
      try {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Starting secure connection...')));
        
        final redirectUrl = await ref.read(consentProvider.notifier).initiateBankConsent();
        
        final result = await FlutterWebAuth2.authenticate(
          url: redirectUrl,
          callbackUrlScheme: 'crednest',
        );

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fetching data securely...')));
        await ref.read(consentProvider.notifier).fetchBankData();
        
        await ref.read(consentProvider.notifier).activateConsent(
          consent.id, 
          expiryDate: DateTime.now().add(const Duration(days: 90))
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bank connected successfully!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error connecting bank: $e')));
        }
      }
      return;
    }

    switch (consent.status) {
      case ConsentStatus.active:
        final confirmed = await showRevokeConsentDialog(context, consentTitle: consent.title);
        if (confirmed) {
          await ref.read(consentProvider.notifier).revokeConsent(consent.id);
        }
        break;
      case ConsentStatus.expired:
        await ref.read(consentProvider.notifier).renewConsent(consent.id);
        break;
      case ConsentStatus.inactive:
      case ConsentStatus.revoked:
        if (mounted) context.push(consent.actionRoute);
        break;
    }
  }

  void _openDetails(ConsentModel consent) {
    context.push('/consent/${consent.id}', extra: consent);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(consentProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _ConnectBankHeader(onBack: () => context.pop()),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ConsentState state) {
    switch (state.status) {
      case ConsentLoadStatus.loading:
        return const _ConsentSkeleton();
      case ConsentLoadStatus.error:
        return _ConsentError(
          message: state.errorMessage ?? 'Unable to load your information.',
          onRetry: () => ref.read(consentProvider.notifier).loadConsents(),
        );
      case ConsentLoadStatus.loaded:
        if (state.consents.isEmpty) {
          return _ConsentEmptyState(onExplore: () => context.push('/connect-bank'));
        }
        return _ConsentList(
          state: state,
          onItemTap: _openDetails,
          onItemAction: _handleAction,
        );
    }
  }
}

class _ConnectBankHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _ConnectBankHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, color: AppColors.navy),
              ),
              const Expanded(
                child: Text(
                  'Connect Bank',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: AppColors.greenTint, shape: BoxShape.circle),
                child: const Icon(Icons.lock_outline, color: AppColors.green, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Review and manage how your data is used\nto build your financial identity.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.subGrey, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsentList extends StatelessWidget {
  final ConsentState state;
  final ValueChanged<ConsentModel> onItemTap;
  final ValueChanged<ConsentModel> onItemAction;

  const _ConsentList({required this.state, required this.onItemTap, required this.onItemAction});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConsentSummaryCard(
            overallLabel: state.overallLabel,
            activeCount: state.activeCount,
            totalCount: state.totalCount,
            activePercent: state.activePercent,
          ),
          const SizedBox(height: 24),
          const Text('Your Consents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
          const SizedBox(height: 12),
          for (final consent in state.consents) ...[
            ConsentItemCard(
              consent: consent,
              onTap: () => onItemTap(consent),
              onAction: () => onItemAction(consent),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          const _ControlInfoCard(),
        ],
      ),
    );
  }
}

class _ControlInfoCard extends StatelessWidget {
  const _ControlInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: AppColors.blueTint, shape: BoxShape.circle),
            child: const Icon(Icons.lock_outline, color: AppColors.blue, size: 18),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("You're in control", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
                SizedBox(height: 3),
                Text('You can revoke consent at any time.', style: TextStyle(fontSize: 12, color: AppColors.subGrey)),
                Text('We will stop using your data immediately.', style: TextStyle(fontSize: 12, color: AppColors.subGrey)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.subGrey),
        ],
      ),
    );
  }
}

class _ConsentSkeleton extends StatelessWidget {
  const _ConsentSkeleton();

  Widget _block({double height = 90, double radius = 20}) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: AppColors.cardBorder.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(radius)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          _block(height: 100),
          const SizedBox(height: 10),
          _block(),
          _block(),
          _block(),
        ],
      ),
    );
  }
}

class _ConsentError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ConsentError({required this.message, required this.onRetry});

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

class _ConsentEmptyState extends StatelessWidget {
  final VoidCallback onExplore;
  const _ConsentEmptyState({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.blueTint, shape: BoxShape.circle),
              child: const Icon(Icons.shield_outlined, color: AppColors.blue, size: 28),
            ),
            const SizedBox(height: 18),
            const Text(
              'No data permissions yet',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect your financial information to begin building your CreditDNA.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.subGrey, height: 1.4),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onExplore,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Explore Data Connections', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
