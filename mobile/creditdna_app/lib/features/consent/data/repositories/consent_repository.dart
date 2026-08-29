import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../models/consent_model.dart';

/// Supplies consent data. No backend exists yet, so this returns demo data
/// shaped exactly like the eventual API response — swap the bodies of these
/// methods for real calls (GET /consents, POST /consents/{id}/revoke,
/// POST /consents/{id}/renew) without touching any caller.
class ConsentRepository {
  // Session-lifetime in-memory cache standing in for a backend — until a
  // real API exists this is the single source of truth so a status change
  // (revoke, renew, activate) is still there the next time the Consent
  // Center is opened, instead of resetting to the demo baseline.
  List<ConsentModel>? _cachedConsents;

  Future<List<ConsentModel>> getConsents() async {
    // TODO(backend): replace with GET /consents
    await Future.delayed(const Duration(milliseconds: 300));
    return _cachedConsents ??= _demoConsents();
  }

  Future<void> revokeConsent(String id) async {
    // TODO(backend): POST /consents/{id}/revoke
    await Future.delayed(const Duration(milliseconds: 400));
    _mutate(id, (c) => c.copyWith(status: ConsentStatus.revoked));
  }

  Future<DateTime> renewConsent(String id) async {
    // TODO(backend): POST /consents/{id}/renew
    await Future.delayed(const Duration(milliseconds: 400));
    final newExpiry = DateTime.now().add(const Duration(days: 30));
    _mutate(id, (c) => c.copyWith(status: ConsentStatus.active, expiryDate: newExpiry));
    return newExpiry;
  }

  /// Marks a consent Active — used once a consent-granting flow (e.g. the
  /// Financial Habits Assessment) completes.
  ///
  /// TEMPORARY: this only updates local in-memory state. It is not a
  /// legally valid consent record until a real backend persists it —
  /// replace with POST /consents/{id}/activate once that exists.
  Future<void> activateConsent(String id, {required DateTime expiryDate}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mutate(id, (c) => c.copyWith(status: ConsentStatus.active, expiryDate: expiryDate));
  }

  void _mutate(String id, ConsentModel Function(ConsentModel) update) {
    final current = _cachedConsents ?? _demoConsents();
    _cachedConsents = [
      for (final c in current)
        if (c.id == id) update(c) else c,
    ];
  }

  List<ConsentModel> _demoConsents() {
    final now = DateTime.now();
    return [
      ConsentModel(
        id: 'financial-data',
        title: 'Financial Data',
        purpose: 'Credit Assessment',
        status: ConsentStatus.active,
        expiryDate: now.add(const Duration(days: 30)),
        icon: Icons.account_balance_outlined,
        accentColor: AppColors.green,
        actionRoute: '/connect-bank',
        whyWeNeedThis: 'To understand your income patterns and financial health for credit assessment.',
        dataRequested: const ['Transaction history', 'Account balances', 'Income patterns'],
        dataNeverAccessed: const ['UPI PIN', 'Bank passwords', 'Debit card PIN'],
      ),
      ConsentModel(
        id: 'gst-data',
        title: 'GST Data',
        purpose: 'Business Verification',
        status: ConsentStatus.active,
        expiryDate: now.add(const Duration(days: 41)),
        icon: Icons.description_outlined,
        accentColor: AppColors.gold,
        actionRoute: '/connect-gst',
        whyWeNeedThis: 'To verify your business activity and revenue trends for a more complete financial profile.',
        dataRequested: const ['GSTIN filing history', 'Turnover trends', 'Business registration details'],
        dataNeverAccessed: const ['GST portal password', 'Bank account details'],
      ),
      ConsentModel(
        id: 'identity-verification',
        title: 'Identity Verification',
        purpose: 'Identity Verification',
        status: ConsentStatus.active,
        expiryDate: now.add(const Duration(days: 9)),
        icon: Icons.badge_outlined,
        accentColor: AppColors.blue,
        actionRoute: '/kyc',
        whyWeNeedThis: 'To confirm your identity and keep your CredNest account secure.',
        dataRequested: const ['Government ID details', 'Name and date of birth', 'Photo verification'],
        dataNeverAccessed: const ['Aadhaar number storage', 'Full ID document copies'],
      ),
      ConsentModel(
        id: 'location-data',
        title: 'Location Data',
        purpose: 'Fraud Prevention',
        status: ConsentStatus.active,
        expiryDate: now.add(const Duration(days: 15)),
        icon: Icons.location_on_outlined,
        accentColor: AppColors.purple,
        actionRoute: '/location-consent',
        whyWeNeedThis: 'To detect unusual account activity and help keep your financial data safe.',
        dataRequested: const ['Approximate location at login', 'Device region'],
        dataNeverAccessed: const ['Continuous location tracking', 'Precise GPS history'],
      ),
      ConsentModel(
        id: 'psychometric-assessment',
        title: 'Psychometric Assessment',
        purpose: 'Creditworthiness Assessment',
        status: ConsentStatus.inactive,
        expiryDate: null,
        icon: Icons.psychology_outlined,
        accentColor: AppColors.gold,
        actionRoute: '/psychometric-quiz',
        whyWeNeedThis: 'To understand financial behavior patterns that complement traditional credit signals.',
        dataRequested: const ['Assessment responses', 'Completion time patterns'],
        dataNeverAccessed: const ['Personal messages', 'Unrelated app activity'],
      ),
    ];
  }
}
