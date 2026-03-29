import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_fonts.dart';

/// 集中管理 App 的 UX 互動細節
/// 包含：觸覺回饋、轉場動畫、全域提示
class AppUX {
  // 避免實例化
  AppUX._();

  // ==========================================
  // 1. 觸覺回饋 (Haptic Feedback)
  // ==========================================

  /// 輕微震動 (用於一般按鈕點擊、Tab切換)
  /// 感覺像：指尖輕輕敲擊
  static Future<void> feedbackClick() async {
    await HapticFeedback.lightImpact();
  }

  /// 選擇震動 (用於 Checkbox、Switch)
  /// 感覺像：撥動機械開關
  static Future<void> feedbackSelection() async {
    await HapticFeedback.selectionClick();
  }

  /// 成功/儲存震動 (用於操作完成)
  /// 感覺像：堅實的敲擊
  static Future<void> feedbackSuccess() async {
    await HapticFeedback.mediumImpact();
  }

  /// 錯誤/刪除震動
  /// 感覺像：兩次快速震動
  static Future<void> feedbackError() async {
    await HapticFeedback.heavyImpact();
  }

  // ==========================================
  // 2. 頁面轉場 (Transitions)
  // ==========================================

  /// 創建一個「淡入淡出 (Fade)」的路由，符合極簡風格
  /// 用法: Navigator.push(context, AppUX.fadeRoute(NextPage()));
  static Route<T> fadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300), // 300ms 是一個舒適的速度
    );
  }

  // ==========================================
  // 3. 懸浮提示框 (Floating Snackbar)
  // ==========================================

  /// 顯示黑底白字的極簡 SnackBar
  static void showSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars(); // 清除舊的
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppFonts.resolve(
            const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor:
            isError ? const Color(0xFFE02E2E) : const Color(0xFF1A1A1A), // 黑或紅
        behavior: SnackBarBehavior.floating, // 懸浮式
        elevation: 0, // 扁平化
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50)), // 膠囊狀
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
