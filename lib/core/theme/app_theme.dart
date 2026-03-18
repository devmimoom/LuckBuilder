import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_fonts.dart';

class AppTheme {
  // 安全地建立文字主題，避免字體載入失敗阻塞應用
  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: AppFonts.resolve(
        const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
      ),
      bodyLarge: AppFonts.resolve(
        const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          height: 1.6,
        ),
      ),
      bodyMedium: AppFonts.resolve(
        const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.accent,
      fontFamily: AppFonts.primary,
      
      // 1. 全域字型設定：主字型 + 數學/符號 fallback
      textTheme: _buildTextTheme(),

      // 2. AppBar 去除陰影，純白乾淨
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false, // iOS 風格靠左
        scrolledUnderElevation: 0, // 捲動時不要變色
        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
        titleTextStyle: AppFonts.resolve(const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        )),
      ),

      // 3. 卡片風格：極淡的邊框代替陰影
      cardTheme: CardThemeData(
        color: AppColors.background,
        elevation: 0, // 去除預設陰影
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border, width: 1), // 1px 細邊框
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.zero,
      ),

      // 4. 按鈕風格：黑底白字，無陰影，膠囊狀
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)), // 膠囊圓角
          textStyle: AppFonts.resolve(
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
        ),
      ),
      
      // 5. 線框按鈕：黑框黑字
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      
      // 6. 輸入框：極簡底線或極淡框
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.textPrimary, width: 1),
        ),
        contentPadding: const EdgeInsets.all(16),
        hintStyle: AppFonts.resolve(const TextStyle(color: AppColors.textTertiary)),
      ),
    );
  }
}

