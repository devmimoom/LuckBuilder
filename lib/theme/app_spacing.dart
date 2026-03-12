import 'package:flutter/material.dart';

/// 全域間距與圓角 token — 僅使用 8 的倍數（8, 16, 24, 32, 40, 48）。
/// 用於 padding、margin、SizedBox、按鈕高度、圓角等，確保視覺節奏一致。
class AppSpacing {
  AppSpacing._();

  // --- Spacing (dp) ---
  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 40;
  static const double xxl = 48;

  // --- Button / touch targets ---
  static const double buttonMinHeight = 48;
  static const double navItemHeight = 72;

  // --- Border radius ---
  static const double radiusXs = 8;
  static const double radiusSm = 16;
  static const double radiusMd = 24;
  static const double radiusLg = 32;

  // --- EdgeInsets helpers ---
  static const EdgeInsets paddingAllXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingAllSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingAllMd = EdgeInsets.all(md);
  static const EdgeInsets paddingAllLg = EdgeInsets.all(lg);

  static const EdgeInsets paddingHorizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets paddingHorizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingVerticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets paddingVerticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets paddingVerticalMd = EdgeInsets.symmetric(vertical: md);
}
