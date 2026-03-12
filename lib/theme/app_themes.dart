import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme_id.dart';
import 'app_tokens.dart';
import 'app_spacing.dart';

// Apply this color migration across the entire project.
// OnePop Color Migration — Dual Theme Spec: Amber Night (dark) + Warm Amber (light).

class AppThemes {
  static ThemeData byId(AppThemeId id) {
    switch (id) {
      case AppThemeId.darkNeon:
        return _darkNeon();
      case AppThemeId.whiteMint:
        return _whiteMint();
    }
  }

  /// Amber Night (dark): amber IS headline/accent. Section titles = amber.
  static ThemeData _darkNeon() {
    const bg = Color(0xFF0C0F1A);
    // Pastel accent palette for dark theme
    const pastelCyan = Color(0xFF5CCCD6);
    const pastelCyanBright = Color(0xFF6ED6DE);
    const pastelPurple = Color(0xFFCC88DD);

    const primary = pastelCyan;
    const primaryLight = pastelCyanBright;
    const textOnPrimary = Color(0xFF0C0F1A);

    const tokens = AppTokens(
      bg: bg,
      bgGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0C0F1A),
          Color(0xFF1A1F35),
          Color(0xFF0C0F1A),
        ],
      ),
      primary: primary,
      primaryBright: primaryLight,
      primaryPale: Color.fromRGBO(92, 204, 214, 0.12),
      sectionTitleColor: primary,
      textPrimary: Color(0xFFEDE8DD),
      textSecondary: Color(0xFF9A9484),
      textMuted: Color(0xFF6B6558),
      textOnPrimary: textOnPrimary,
      cardBg: Color(0xFF151929),
      cardBorder: Color.fromRGBO(92, 204, 214, 0.12),
      cardRadius: 24,
      cardShadow: [
        BoxShadow(
          color: Color.fromRGBO(92, 204, 214, 0.05),
          blurRadius: 80,
          offset: Offset(0, 16),
        ),
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.35),
          blurRadius: 24,
          offset: Offset(0, 16),
        ),
      ],
      cardGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.fromRGBO(255, 247, 173, 0.08),
          Color.fromRGBO(255, 169, 249, 0.06),
        ],
      ),
      chipBg: Color(0xFF1C2139),
      chipGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.fromRGBO(255, 247, 173, 0.10),
          Color.fromRGBO(255, 169, 249, 0.08),
        ],
      ),
      navBg: Color.fromRGBO(20, 24, 44, 0.72),
      navGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.fromRGBO(20, 24, 44, 0.85),
          Color.fromRGBO(11, 14, 26, 0.95),
        ],
      ),
      buttonGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [pastelCyan, pastelPurple],
      ),
      searchBarGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.fromRGBO(255, 255, 255, 0.12),
          Color.fromRGBO(255, 255, 255, 0.08),
        ],
      ),
      glassBlurSigma: 18,
    );

    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: primary,
        surface: tokens.cardBg,
        // ✅ 修復深色主題下拉選單：確保 surfaceContainerHighest 使用不透明背景
        surfaceContainerHighest: const Color(0xFF14182E),
      ),
      textTheme: GoogleFonts.notoSansTcTextTheme(const TextTheme(
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(fontSize: 15, height: 1.35),
        bodySmall: TextStyle(fontSize: 13, height: 1.35),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color.fromRGBO(255, 255, 255, 0.10),
        hintStyle: const TextStyle(color: Color.fromRGBO(255, 255, 255, 0.60)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide:
              const BorderSide(color: Color.fromRGBO(255, 255, 255, 0.14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide:
              const BorderSide(color: Color.fromRGBO(255, 255, 255, 0.14)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: primary, width: 1.2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      // ✅ 修復深色主題下拉選單透明背景重疊問題
      // DropdownButton 使用 Menu widget，需要配置 menuTheme
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(
            const Color(0xFF14182E), // 使用不透明的深色背景，避免透明重疊
          ),
          elevation: WidgetStateProperty.all(8),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
            ),
          ),
        ),
      ),
      // DropdownMenu widget 的主題配置
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(
            const Color(0xFF14182E), // 使用不透明的深色背景，避免透明重疊
          ),
          elevation: WidgetStateProperty.all(8),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
            ),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.buttonMinHeight),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.buttonMinHeight),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.buttonMinHeight),
        ),
      ),
    );

    return base.copyWith(extensions: [tokens]);
  }

  /// Warm Amber (light): section titles = near-black. Amber only for buttons/links/accent bar.
  static ThemeData _whiteMint() {
    const bg = Color(0xFFFAF8F4);
    // Pastel accent palette for light theme (aligned with dark theme hues)
    const pastelCyan = Color(0xFF3BB5C0);
    const pastelCyanBright = Color(0xFF4DC5D0);
    const pastelPurple = Color(0xFFB870C8);

    const primary = pastelCyan;
    const primaryBright = pastelCyanBright;
    const primaryPale = Color(0xFFE8F6F8);

    const tokens = AppTokens(
      bg: bg,
      bgGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFAF8F4),
          Color(0xFFF5F2EC),
          Color(0xFFFAF8F4),
        ],
      ),
      primary: primary,
      primaryBright: primaryBright,
      primaryPale: primaryPale,
      sectionTitleColor: Color(0xFF2A5C62),
      textPrimary: Color(0xFF1A1710),
      textSecondary: Color(0xFF6B6152),
      textMuted: Color(0xFF9A9080),
      textOnPrimary: Color(0xFFFFFFFF),
      cardBg: Color(0xFFFFFFFF),
      cardBorder: Color.fromRGBO(59, 181, 192, 0.20),
      cardRadius: AppSpacing.radiusMd,
      cardShadow: [
        BoxShadow(
          color: Color.fromRGBO(26, 23, 16, 0.06),
          blurRadius: 16,
          offset: Offset(0, 8),
        ),
      ],
      cardGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFBF0),
          Color(0xFFFFF5F8),
        ],
      ),
      chipBg: Color(0xFFEEF6F7),
      chipGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFF8EC),
          Color(0xFFFFF0F5),
        ],
      ),
      navBg: Color(0xFFFFFFFF),
      navGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFFFFFFF),
        ],
      ),
      buttonGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, pastelPurple],
      ),
      searchBarGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF5F2EC),
          Color(0xFFF0EDE6),
        ],
      ),
      glassBlurSigma: 10,
    );

    final base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: primary,
        surface: tokens.cardBg,
      ),
      textTheme: GoogleFonts.notoSansTcTextTheme(const TextTheme(
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(fontSize: 15, height: 1.35),
        bodySmall: TextStyle(fontSize: 13, height: 1.35),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF6F7FB),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: Color(0xFFEEF1F6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: Color(0xFFEEF1F6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: primary, width: 1.2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      // ✅ 淺色主題下拉選單主題配置
      // DropdownButton 使用 Menu widget，需要配置 menuTheme
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(
            Colors.white, // 淺色主題使用白色背景
          ),
          elevation: WidgetStateProperty.all(8),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
            ),
          ),
        ),
      ),
      // DropdownMenu widget 的主題配置
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(
            Colors.white, // 淺色主題使用白色背景
          ),
          elevation: WidgetStateProperty.all(8),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
            ),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.buttonMinHeight),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.buttonMinHeight),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.buttonMinHeight),
        ),
      ),
    );

    return base.copyWith(extensions: [tokens]);
  }
}
