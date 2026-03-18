import 'package:flutter/material.dart';

class AppFonts {
  static const String primary = 'NotoSansTC';
  static const String math = 'NotoSansMath';
  static const String symbols = 'NotoSansSymbols2';

  static const List<String> fallback = <String>[
    math,
    symbols,
  ];

  static TextStyle resolve(TextStyle? base) {
    final style = base ?? const TextStyle();
    return style.copyWith(
      fontFamily: style.fontFamily ?? primary,
      fontFamilyFallback: style.fontFamilyFallback ?? fallback,
    );
  }
}
