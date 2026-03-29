import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

const _defaultEntitlementId = 'premium';
const _packageWeekly = r'$rc_weekly';
const _packageMonthly = r'$rc_monthly';
const _packageAnnual = r'$rc_annual';

enum EntitlementStatus {
  trial,
  expired,
  subscribed,
}

class EntitlementState {
  const EntitlementState({
    required this.status,
    required this.trialDaysRemaining,
    required this.hasAccess,
    this.startDate,
  });

  final EntitlementStatus status;
  final int trialDaysRemaining;
  final bool hasAccess;
  final DateTime? startDate;

  const EntitlementState.initial()
      : status = EntitlementStatus.expired,
        trialDaysRemaining = 0,
        hasAccess = false,
        startDate = null;

  EntitlementState copyWith({
    EntitlementStatus? status,
    int? trialDaysRemaining,
    bool? hasAccess,
    DateTime? startDate,
  }) {
    return EntitlementState(
      status: status ?? this.status,
      trialDaysRemaining: trialDaysRemaining ?? this.trialDaysRemaining,
      hasAccess: hasAccess ?? this.hasAccess,
      startDate: startDate ?? this.startDate,
    );
  }
}

final entitlementProvider =
    StateNotifierProvider<EntitlementNotifier, EntitlementState>(
  (ref) => EntitlementNotifier(),
);

class EntitlementNotifier extends StateNotifier<EntitlementState> {
  EntitlementNotifier() : super(const EntitlementState.initial()) {
    refreshEntitlement();
  }

  Future<void> refreshEntitlement() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final hasPremium =
          customerInfo.entitlements.active[_entitlementId] != null;
      state = EntitlementState(
        status:
            hasPremium ? EntitlementStatus.subscribed : EntitlementStatus.expired,
        trialDaysRemaining: 0,
        hasAccess: hasPremium,
      );
    } catch (_) {
      state = state.copyWith(
        status: EntitlementStatus.expired,
        hasAccess: false,
        trialDaysRemaining: 0,
      );
    }
  }

  Future<void> purchaseByPlanId(String planId) async {
    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    if (current == null) {
      throw StateError('尚未設定可用方案（Offering current 為空）');
    }

    final packageId = switch (planId) {
      'weekly' => _packageWeekly,
      'monthly' => _packageMonthly,
      'yearly' => _packageAnnual,
      _ => _packageMonthly,
    };
    Package? target;
    for (final pkg in current.availablePackages) {
      if (pkg.identifier == packageId) {
        target = pkg;
        break;
      }
    }
    if (target == null) {
      throw StateError('找不到方案：$packageId');
    }

    await Purchases.purchasePackage(target);
    await refreshEntitlement();
  }

  Future<void> restorePurchases() async {
    await Purchases.restorePurchases();
    await refreshEntitlement();
  }

  String get _entitlementId =>
      dotenv.get('REVENUECAT_ENTITLEMENT_ID', fallback: _defaultEntitlementId);
}
