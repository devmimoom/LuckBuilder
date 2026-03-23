import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_spacing.dart';

class AppTheme {
  static TextTheme _buildTextTheme() {
    return TextTheme(
      // ── Display：頁面主視覺大標 ─────────────────────────────
      displayLarge: AppFonts.resolve(const TextStyle(
        color: AppColors.textPrimary,
        fontSize: AppFonts.sizeDisplayLg,
        fontWeight: AppFonts.weightBold,
        height: AppFonts.lineHeightTight,
        letterSpacing: AppFonts.letterSpacingTitle,
      )),
      displayMedium: AppFonts.resolve(const TextStyle(
        color: AppColors.textPrimary,
        fontSize: AppFonts.sizeDisplayMd,
        fontWeight: AppFonts.weightBold,
        height: AppFonts.lineHeightTight,
        letterSpacing: AppFonts.letterSpacingTitle,
      )),

      // ── Headline：Section / 卡片大標 ────────────────────────
      headlineLarge: AppFonts.resolve(const TextStyle(
        color: AppColors.textPrimary,
        fontSize: AppFonts.sizeHeading,
        fontWeight: AppFonts.weightSemibold,
        height: AppFonts.lineHeightTight,
        letterSpacing: AppFonts.letterSpacingTitle,
      )),
      headlineMedium: AppFonts.resolve(const TextStyle(
        color: AppColors.textPrimary,
        fontSize: AppFonts.sizeTitleLg,
        fontWeight: AppFonts.weightSemibold,
        height: AppFonts.lineHeightTight,
      )),

      // ── Title：卡片標題 ──────────────────────────────────────
      titleLarge: AppFonts.resolve(const TextStyle(
        color: AppColors.textPrimary,
        fontSize: AppFonts.sizeTitleLg,
        fontWeight: AppFonts.weightSemibold,
        height: AppFonts.lineHeightTight,
      )),
      titleMedium: AppFonts.resolve(const TextStyle(
        color: AppColors.textPrimary,
        fontSize: AppFonts.sizeTitleMd,
        fontWeight: AppFonts.weightSemibold,
        height: AppFonts.lineHeightTight,
      )),
      titleSmall: AppFonts.resolve(const TextStyle(
        color: AppColors.textPrimary,
        fontSize: AppFonts.sizeTitleSm,
        fontWeight: AppFonts.weightSemibold,
        height: AppFonts.lineHeightTight,
      )),

      // ── Body：內文（降低飽和度以拉開層次）─────────────────────
      bodyLarge: AppFonts.resolve(const TextStyle(
        color: AppColors.textPrimary,
        fontSize: AppFonts.sizeBodyLg,
        fontWeight: AppFonts.weightRegular,
        height: AppFonts.lineHeightBody,
      )),
      bodyMedium: AppFonts.resolve(const TextStyle(
        color: AppColors.textSecondary,
        fontSize: AppFonts.sizeBodySm,
        fontWeight: AppFonts.weightRegular,
        height: AppFonts.lineHeightBody,
      )),
      bodySmall: AppFonts.resolve(const TextStyle(
        color: AppColors.textSecondary,
        fontSize: AppFonts.sizeCaption,
        fontWeight: AppFonts.weightRegular,
        height: AppFonts.lineHeightRelaxed,
      )),

      // ── Label：輔助說明 / Tag ────────────────────────────────
      labelLarge: AppFonts.resolve(const TextStyle(
        color: AppColors.textPrimary,
        fontSize: AppFonts.sizeCaption,
        fontWeight: AppFonts.weightMedium,
        letterSpacing: AppFonts.letterSpacingButton,
      )),
      labelMedium: AppFonts.resolve(const TextStyle(
        color: AppColors.textTertiary,
        fontSize: AppFonts.sizeBadge,
        fontWeight: AppFonts.weightMedium,
        letterSpacing: AppFonts.letterSpacingButton,
      )),
      labelSmall: AppFonts.resolve(const TextStyle(
        color: AppColors.textTertiary,
        fontSize: AppFonts.sizeXs,
        fontWeight: AppFonts.weightRegular,
      )),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.accent,
      fontFamily: AppFonts.primary,

      textTheme: _buildTextTheme(),

      // ── AppBar：去除陰影，iOS 風格靠左 ───────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
        titleTextStyle: AppFonts.resolve(const TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppFonts.sizeTitleLg,
          fontWeight: AppFonts.weightSemibold,
          letterSpacing: AppFonts.letterSpacingTitle,
        )),
      ),

      // ── 卡片：圓角 16px，極淡邊框代替陰影 ───────────────────
      cardTheme: CardThemeData(
        color: AppColors.background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border, width: 1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── ElevatedButton：黑底白字，膠囊圓角 ──────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          textStyle: AppFonts.resolve(const TextStyle(
            fontSize: AppFonts.sizeBodyLg,
            fontWeight: AppFonts.weightSemibold,
            letterSpacing: AppFonts.letterSpacingButton,
          )),
        ),
      ),

      // ── OutlinedButton：黑框黑字 ─────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border, width: 1),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),

      // ── InputDecoration：極簡填充框 ─────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.textPrimary, width: 1),
        ),
        contentPadding: AppSpacing.cardPaddingMd,
        hintStyle: AppFonts.resolve(
          const TextStyle(color: AppColors.textTertiary),
        ),
      ),
    );
  }
}
