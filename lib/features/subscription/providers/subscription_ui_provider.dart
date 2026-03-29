import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 訂閱方案資料結構。
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.label,
    required this.price,
    required this.unit,
    this.badgeText,
    this.savingsNote,
  });

  final String id;
  final String label;
  final int price;
  final String unit;

  /// 右上角 badge 文案（例如「推薦」），null 代表不顯示。
  final String? badgeText;

  /// 附加說明文案（例如「每月約 NT$141，省最多」）。
  final String? savingsNote;

  String get priceLabel => 'NT\$$price';

  String get ctaLabel => '以 NT\$$price/$unit 訂閱';
}

/// 所有方案定義（依序：週、月、年）。
const List<SubscriptionPlan> kSubscriptionPlans = [
  SubscriptionPlan(
    id: 'weekly',
    label: '一週',
    price: 120,
    unit: '週',
  ),
  SubscriptionPlan(
    id: 'monthly',
    label: '一月',
    price: 320,
    unit: '月',
    badgeText: '推薦',
  ),
  SubscriptionPlan(
    id: 'yearly',
    label: '一年',
    price: 1690,
    unit: '年',
    savingsNote: '每月約 NT\$141，省最多',
  ),
];

/// 目前選中方案的 index（預設選月方案 = index 1）。
final selectedPlanIndexProvider = StateProvider<int>((ref) => 1);
