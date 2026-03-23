import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_fonts.dart';

/// 首頁專用字體策略：
/// - **iOS**：`PingFang TC`（蘋方）+ `NotoSansTC`／數學符號 fallback。
/// - **其他平台**：`Inter`（英數為主）+ `NotoSansTC` 等 fallback（中文自動落到思源黑體）。
///
/// 字重：大標 **Bold**，區塊／次標 **Semibold**，內文與說明 **Regular**；Badge／小標 **Semibold**。
abstract final class HomePageFonts {
  static List<String> get _fallback => <String>[
        'NotoSansTC',
        AppFonts.math,
        AppFonts.symbols,
      ];

  /// 套上首頁字族（不覆寫已指定的 `fontFamily`，供特殊情況）。
  static TextStyle resolve(TextStyle? base) {
    final style = base ?? const TextStyle();
    if (Platform.isIOS) {
      return style.copyWith(
        fontFamily: style.fontFamily ?? 'PingFang TC',
        fontFamilyFallback: style.fontFamilyFallback ?? _fallback,
      );
    }
    return GoogleFonts.inter(textStyle: style).copyWith(
      fontFamilyFallback: _fallback,
    );
  }

  // ── 標題層級（Semibold / Bold）──────────────────────────────────

  /// 大區塊主標（如「拍題解題」）— **Bold**
  static TextStyle displayMd(Color color) => resolve(TextStyle(
        fontSize: AppFonts.sizeDisplayMd,
        fontWeight: AppFonts.weightBold,
        height: AppFonts.lineHeightTight,
        letterSpacing: AppFonts.letterSpacingTitle,
        color: color,
      ));

  /// Section 標題（如「最近錯題」）— **Semibold**
  static TextStyle heading(Color color) => resolve(TextStyle(
        fontSize: AppFonts.sizeHeading,
        fontWeight: AppFonts.weightSemibold,
        height: AppFonts.lineHeightTight,
        letterSpacing: AppFonts.letterSpacingTitle,
        color: color,
      ));

  /// 卡片／區塊次標 — **Semibold**
  static TextStyle titleSm(Color color) => resolve(TextStyle(
        fontSize: AppFonts.sizeTitleSm,
        fontWeight: AppFonts.weightSemibold,
        height: AppFonts.lineHeightTight,
        color: color,
      ));

  /// Tag／Badge — **Semibold**（小字仍保持可辨識）
  static TextStyle badge(Color color) => resolve(TextStyle(
        fontSize: AppFonts.sizeBadge,
        fontWeight: AppFonts.weightSemibold,
        letterSpacing: AppFonts.letterSpacingButton,
        color: color,
      ));

  // 尺寸／行高仍沿用 [AppFonts] 常數，避免首頁與全站數字不一致。
}
