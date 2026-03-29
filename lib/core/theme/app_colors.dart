import 'package:flutter/material.dart';

class AppColors {
  // 1. 背景色：不是死白，而是極致的紙張白 (Paper White)
  static const Color background = Color(0xFFFFFFFF);
  /// 次要區塊／輸入底；在彌散底上常搭配 `withValues(alpha: …)`。
  static const Color surface = Color(0xFFFAFAFA);

  // 2. 文字色：避免純黑 (#000000)，使用「碳黑」與「石墨灰」
  static const Color textPrimary = Color(0xFF1A1A1A); // 主標題
  static const Color textSecondary = Color(0xFF666666); // 次要資訊
  static const Color textTertiary = Color(0xFFAAAAAA); // 輔助說明

  // 3. 線條與邊框：極細、若有似無
  static const Color border = Color(0xFFE5E5E5); // 淺灰分隔線

  // 4. 功能色：極簡主義通常只用一個強調色
  static const Color accent = Color(0xFF1A1A1A); // 按鈕通常用黑色，顯得高級
  static const Color highlight = Color(0xFF007AFF); // 科技藍，只用於連結或勾選
  static const Color error = Color(0xFFE02E2E); // 錯誤紅
}
