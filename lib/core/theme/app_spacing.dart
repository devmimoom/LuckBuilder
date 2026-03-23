import 'package:flutter/material.dart';

/// 8pt 網格間距系統
/// 所有間距均為 8 的倍數，確保視覺節奏一致
class AppSpacing {
  // ── 基礎間距單位（8pt 網格）──────────────────────────────────
  static const double xs = 4.0;   // 極小：標題與副標題間距
  static const double sm = 8.0;   // 小：元素內部間隙
  static const double md = 12.0;  // 中：卡片與卡片間距
  static const double lg = 16.0;  // 大：小卡片 padding、安全邊距
  static const double xl = 20.0;  // 特大：螢幕左右安全邊距
  static const double xxl = 24.0; // 超大：大卡片 padding、Section 間距


  // ── 圓角系統（由外而內遞減）─────────────────────────────────
  /// 大卡片（Hero Card、Welcome Card）
  static const double radiusLg = 24.0;
  /// 小卡片（Compact Card、功能方塊）
  static const double radiusMd = 18.0;
  /// 內層元素（按鈕、Icon 容器）— 比外層縮小以維持和諧感
  static const double radiusSm = 14.0;
  /// 圖示容器圓角（比 radiusSm 再小一階）
  static const double radiusIcon = 12.0;
  /// 最小圓角（Tag、Badge、小標籤）
  static const double radiusXs = 10.0;
  /// 膠囊型（Pill）— 完全圓角
  static const double radiusPill = 999.0;

  // ── 補充間距（非 8pt 但常用的值）────────────────────────────
  /// 6px — 標題與副標題之間、元素內部最小間隙
  static const double tight = 6.0;
  /// 10px — Badge 水平 padding、緊湊元素內距
  static const double compact = 10.0;
  /// 14px — 卡片內區塊 padding（介於 sm 與 lg 之間）
  static const double snug = 14.0;
  /// 18px — 空狀態卡片內距（與 radiusMd 等值，視覺平衡）
  static const double inset = 18.0;

  // ── 常用 EdgeInsets 快捷組合 ─────────────────────────────────
  /// 螢幕整體安全邊距（ListView padding）
  static const EdgeInsets screenPadding = EdgeInsets.all(xl);

  /// 大卡片內部填充（Welcome Card、Hero Card）
  static const EdgeInsets cardPaddingLg = EdgeInsets.all(xxl);

  /// 小卡片內部填充（Compact Card）
  static const EdgeInsets cardPaddingMd = EdgeInsets.all(lg);

  /// 緊湊元素（Pill 內區塊、子元件）填充
  static const EdgeInsets paddingSnug = EdgeInsets.all(snug);

  /// 卡片與卡片之間的垂直間距
  static const SizedBox gapCard = SizedBox(height: md);

  /// 同排雙欄卡片的水平間距
  static const SizedBox gapCardRow = SizedBox(width: md);

  /// 大區塊（Section）之間的間距
  static const SizedBox gapSection = SizedBox(height: xxl);
}
