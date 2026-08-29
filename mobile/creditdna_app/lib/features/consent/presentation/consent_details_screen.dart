import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../application/consent_provider.dart';
import '../data/models/consent_model.dart';
import 'widgets/consent_status_badge.dart';
import 'widgets/revoke_consent_dialog.dart';

class ConsentDetailsScreen extends ConsumerStatefulWidget {
  final String consentId;
  final ConsentModel? initialConsent;

  const ConsentDetailsScreen({super.key, required this.consentId, this.initialConsent});

  @override
  ConsumerState<ConsentDetailsScreen> createState() => _ConsentDetailsScreenState();
}

class _ConsentDetailsScreenState extends ConsumerState<ConsentDetailsScreen> {
  ConsentModel? _consent;
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    _consent = widget.initialConsent ?? _findInProvider();
  }

  ConsentModel? _findInProvider() {
    final consents = ref.read(consentProvider).consents;
    for (final c in consents) {
      if (c.id == widget.consentId) return c;
    }
    return null;
  }

  void _refreshFromProvider() {
    final updated = _findInProvider();
    if (updated != null) setState(() => _consent = updated);
  }

  Future<void> _revoke() async {
    final consent = _consent;
    if (consent == null) return;
    final confirmed = await showRevokeConsentDialog(context, consentTitle: consent.title);
    if (!confirmed) return;
    setState(() => _isActing = true);
    await ref.read(consentProvider.notifier).revokeConsent(consent.id);
    if (!mounted) return;
    setState(() => _isActing = false);
    _refreshFromProvider();
  }

  Future<void> _renew() async {
    final consent = _consent;
    if (consent == null) return;
    setState(() => _isActing = true);
    await ref.read(consentProvider.notifier).renewConsent(consent.id);
    if (!mounted) return;
    setState(() => _isActing = false);
    _refreshFromProvider();
  }

  @override
  Widget build(BuildContext context) {
    final consent = _consent;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                  ),
                  Expanded(
                    child: Text(
                      consent?.title ?? 'Consent Details',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: consent == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          "We couldn't find details for this consent.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.subGrey),
                        ),
                      ),
                    )
                  : _ConsentDetailsBody(
                      consent: consent,
                      isActing: _isActing,
                      onRevoke: _revoke,
                      onRenew: _renew,
                      onProvide: () => context.push(consent.actionRoute),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentDetailsBody extends StatelessWidget {
  final ConsentModel consent;
  final bool isActing;
  final VoidCallback onRevoke;
  final VoidCallback onRenew;
  final VoidCallback onProvide;

  const _ConsentDetailsBody({
    required this.consent,
    required this.isActing,
    required this.onRevoke,
    required this.onRenew,
    required this.onProvide,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: consent.accentColor.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(consent.icon, color: consent.accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(consent.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('Status: ', style: TextStyle(fontSize: 13, color: AppColors.subGrey)),
                        ConsentStatusBadge(status: consent.status),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          _SectionCard(
            title: 'Why we need this',
            child: Text(consent.whyWeNeedThis, style: const TextStyle(fontSize: 13.5, color: AppColors.subGrey, height: 1.45)),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Data requested',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in consent.dataRequested) _BulletRow(text: item, icon: Icons.check, color: AppColors.green),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'We never access',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in consent.dataNeverAccessed) _BulletRow(text: item, icon: Icons.close, color: AppColors.errorRed),
              ],
            ),
          ),
          if (consent.expiryDate != null) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Access expires',
              child: Text(
                _formatDate(consent.expiryDate!),
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.navy),
              ),
            ),
          ],
          const SizedBox(height: 28),
          if (consent.status == ConsentStatus.active) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isActing ? null : onRenew,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: isActing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : const Text('Renew Consent', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: isActing ? null : onRevoke,
                child: const Text('Revoke Consent', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w700)),
              ),
            ),
          ] else if (consent.status == ConsentStatus.expired) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isActing ? null : onRenew,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: isActing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : const Text('Renew Consent', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onProvide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Provide Consent', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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

class _BulletRow extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _BulletRow({required this.text, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, color: AppColors.navy, height: 1.3))),
        ],
      ),
    );
  }
}

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _formatDate(DateTime date) => '${date.day} ${_monthNames[date.month - 1]} ${date.year}';
