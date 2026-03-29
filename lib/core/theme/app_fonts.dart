import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 全站字體（與首頁一致）
///
/// - **iOS**：`PingFang TC` + NotoSansTC／數學／符號 fallback。
/// - **其他平台**：`Inter` + 同上 fallback（中文落到思源黑體）。
class AppFonts {
  // ── 字體家族 ─────────────────────────────────────────────────
  static const String primary = 'NotoSansTC';
  static const String math = 'NotoSansMath';
  static const String symbols = 'NotoSansSymbols2';

  static const List<String> fallback = <String>[math, symbols];

  static List<String> get _resolvedFallback =>
      <String>[primary, math, symbols];

  // ── 字重常數 ─────────────────────────────────────────────────
  /// 標題用：增加視覺錨點
  static const FontWeight weightBold = FontWeight.w700;
  /// 次標題 / 強調文字
  static const FontWeight weightSemibold = FontWeight.w600;
  /// 中等強調
  static const FontWeight weightMedium = FontWeight.w500;
  /// 一般內文（降低飽和度搭配，拉開層次）
  static const FontWeight weightRegular = FontWeight.w400;

  // ── 行高常數（中文字建議 1.5 ～ 1.6）────────────────────────
  /// 標題行高（緊湊，適合大字）
  static const double lineHeightTight = 1.25;
  /// 一般內文（適合 14-16px 正文）
  static const double lineHeightBody = 1.55;
  /// 說明文字（寬鬆，適合輔助說明）
  static const double lineHeightRelaxed = 1.6;

  // ── 字距微調 ─────────────────────────────────────────────────
  /// 標題字距（微量增加，提升清晰感）
  static const double letterSpacingTitle = 0.2;
  /// 按鈕 / Badge 字距
  static const double letterSpacingButton = 0.4;

  // ── 主要字型尺寸 ─────────────────────────────────────────────
  static const double sizeDisplayLg = 28.0;  // 頁面主標題
  static const double sizeDisplayMd = 24.0;  // 大卡片標題（如「拍題解題」）
  static const double sizeHeading = 20.0;    // Section 標題
  static const double sizeTitleLg = 18.0;    // AppBar 標題
  static const double sizeTitleMd = 16.0;    // 卡片主標題
  static const double sizeTitleSm = 15.0;    // 次要標題
  static const double sizeBodyLg = 14.0;     // 標準內文
  static const double sizeBodySm = 13.0;     // 說明文字
  static const double sizeCaption = 12.0;    // Label / 最小文字
  static const double sizeBadge = 11.0;      // Tag / Badge
  static const double sizeXs = 10.0;         // 極小文字（labelSmall）

  // ── 核心方法：依平台套用字族 + fallback ──────────────────────
  static TextStyle resolve(TextStyle? base) {
    final style = base ?? const TextStyle();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return style.copyWith(
        fontFamily: style.fontFamily ?? 'PingFang TC',
        fontFamilyFallback: style.fontFamilyFallback ?? _resolvedFallback,
      );
    }
    return GoogleFonts.inter(textStyle: style).copyWith(
      fontFamilyFallback: style.fontFamilyFallback ?? _resolvedFallback,
    );
  }

  // ── 快捷 TextStyle 建構器 ────────────────────────────────────

  /// 大卡片主標題（如「拍題解題」）
  static TextStyle displayMd(Color color) => resolve(TextStyle(
        fontSize: sizeDisplayMd,
        fontWeight: weightBold,
        height: lineHeightTight,
        letterSpacing: letterSpacingTitle,
        color: color,
      ));

  /// Section 標題（如「最近錯題」）
  static TextStyle heading(Color color) => resolve(TextStyle(
        fontSize: sizeHeading,
        fontWeight: weightSemibold,
        height: lineHeightTight,
        letterSpacing: letterSpacingTitle,
        color: color,
      ));

  /// 次要標題
  static TextStyle titleSm(Color color) => resolve(TextStyle(
        fontSize: sizeTitleSm,
        fontWeight: weightSemibold,
        height: lineHeightTight,
        color: color,
      ));

  /// 標籤 / Badge 文字
  static TextStyle badge(Color color) => resolve(TextStyle(
        fontSize: sizeBadge,
        fontWeight: weightSemibold,
        letterSpacing: letterSpacingButton,
        color: color,
      ));
}
