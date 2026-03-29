import 'package:flutter/material.dart';

import 'app_fonts.dart';

/// 首頁歷史別名：邏輯已併入 [AppFonts]，此處僅轉接。
abstract final class HomePageFonts {
  static TextStyle resolve(TextStyle? base) => AppFonts.resolve(base);

  static TextStyle displayMd(Color color) => AppFonts.displayMd(color);

  static TextStyle heading(Color color) => AppFonts.heading(color);

  static TextStyle titleSm(Color color) => AppFonts.titleSm(color);

  static TextStyle badge(Color color) => AppFonts.badge(color);
}
