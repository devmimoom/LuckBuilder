import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/services/revenuecat_service.dart';

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.label,
    required this.unit,
    required this.productId,
    required this.packageId,
    this.isPrimary = false,
    this.showOnMainPaywall = true,
    this.badgeText,
    this.savingsNote,
    this.promoCopy,
  });

  final String id;
  final String label;
  final String unit;
  final String productId;
  final String packageId;
  final bool isPrimary;
  final bool showOnMainPaywall;
  final String? badgeText;
  final String? savingsNote;
  final String? promoCopy;
}

/// 上架僅販售月訂；年／週仍保留於此清單，供舊訂閱與後端 `planId` 對照顯示。
const List<SubscriptionPlan> kSubscriptionPlans = [
  SubscriptionPlan(
    id: 'yearly',
    label: '一年',
    unit: '年',
    productId: 'lucklab_premium_yearly',
    packageId: r'$rc_annual',
    showOnMainPaywall: false,
    savingsNote: '每月約 {pricePerMonth}，省最多',
    promoCopy: '一年最省，平均每月更划算',
  ),
  SubscriptionPlan(
    id: 'monthly',
    label: '月方案',
    unit: '月',
    productId: 'lucklab_premium_monthly',
    packageId: r'$rc_monthly',
    isPrimary: true,
    showOnMainPaywall: true,
    promoCopy: '主打推薦：AI 功能不限次使用',
  ),
  SubscriptionPlan(
    id: 'weekly',
    label: '一週',
    unit: '週',
    productId: 'lucklab_premium_weekly',
    packageId: r'$rc_weekly',
    showOnMainPaywall: false,
    promoCopy: '短期試用，快速解鎖完整功能',
  ),
];

List<SubscriptionPlan> get kMainPaywallPlans => kSubscriptionPlans
    .where((plan) => plan.showOnMainPaywall)
    .toList(growable: false);

SubscriptionPlan subscriptionPlanById(String planId) {
  return kSubscriptionPlans.firstWhere(
    (plan) => plan.id == planId,
    orElse: () => kSubscriptionPlans.firstWhere((p) => p.id == 'monthly'),
  );
}

SubscriptionPlan? subscriptionPlanByProductId(String? productId) {
  if (productId == null || productId.isEmpty) {
    return null;
  }

  const aliasToCanonicalProductId = <String, String>{
    'luckbuilder.monthly': 'lucklab_premium_monthly',
    'luckbuilder.yearly': 'lucklab_premium_yearly',
    'luckbuilder.weekly': 'lucklab_premium_weekly',
  };
  final normalizedProductId =
      aliasToCanonicalProductId[productId] ?? productId;

  for (final plan in kSubscriptionPlans) {
    if (plan.productId == normalizedProductId) {
      return plan;
    }
  }
  return null;
}

class SubscriptionPlanOffer {
  const SubscriptionPlanOffer({
    required this.plan,
    required this.package,
  });

  final SubscriptionPlan plan;
  final Package package;

  StoreProduct get storeProduct => package.storeProduct;

  String get priceLabel {
    final override = _priceLabelOverrideForPlanId(plan.id);
    return override ?? storeProduct.priceString;
  }

  String get pricePerMonthLabel =>
      storeProduct.pricePerMonthString ?? storeProduct.priceString;

  String get ctaLabel => '以 $priceLabel/${plan.unit} 訂閱';

  String? get resolvedSavingsNote {
    final template = plan.savingsNote;
    if (template == null) {
      return null;
    }
    return template.replaceAll('{pricePerMonth}', pricePerMonthLabel);
  }
}

String? _priceLabelOverrideForPlanId(String planId) {
  // 僅覆寫 UI 顯示，不影響實際扣款（以 App Store / Google Play 為準）。
  if (planId == 'monthly') {
    return 'NT\$190';
  }
  return null;
}

final selectedPlanIdProvider = StateProvider<String>((ref) => 'monthly');

final subscriptionPlanOffersProvider =
    FutureProvider<List<SubscriptionPlanOffer>>((ref) async {
  final offerings = await RevenueCatService.instance.getOfferings();
  final current = offerings.current;
  if (current == null) {
    throw StateError('尚未設定可用方案（Offering current 為空）');
  }

  final packagesByIdentifier = {
    for (final pkg in current.availablePackages) pkg.identifier: pkg,
  };

  final offers = <SubscriptionPlanOffer>[];
  for (final plan in kMainPaywallPlans) {
    final package = packagesByIdentifier[plan.packageId];
    if (package == null) {
      throw StateError('RevenueCat 缺少方案：${plan.packageId}');
    }
    offers.add(SubscriptionPlanOffer(plan: plan, package: package));
  }
  return offers;
});
