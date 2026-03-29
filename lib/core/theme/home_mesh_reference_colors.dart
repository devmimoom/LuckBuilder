import 'package:flutter/material.dart';

/// 首頁（彌散漸變 + 玻璃）之色票：**莫蘭迪＋藕粉**（低飽和、偏粉嫩）。
abstract final class HomeMeshReferenceColors {
  /// 霧薄荷粉綠。
  static const Color teal = Color(0xFFA8B8B0);
  /// 蜜桃藕粉。
  static const Color peach = Color(0xFFD8B8B0);
  /// 藕荷粉紫。
  static const Color lavender = Color(0xFFC4A8BE);
  /// 豆沙粉（徽標／強調）。
  static const Color accentPurple = Color(0xFFC49AAC);

  /// 霧玫瑰（彌散加層用）。
  static const Color pinkMist = Color(0xFFE8C4D0);

  static const Color darkGlass = Color(0xFF3E3639);

  /// 彌散底（預設「藕粉霧」主題）：偏粉的天光，仍維持偏亮少灰。
  static const Color meshBaseTop = Color(0xFFFFF2F7);
  static const Color meshBaseMid = Color(0xFFFFE8F1);

  static const double darkGlassOpacity = 0.65;

  /// 首頁第一張歡迎卡：略提高透明度，讓彌散底更透出。
  static const double welcomeCardGlassOpacity = 0.46;

  /// 首頁六張功能小卡漸層填色不透明度（略透以露出彌散底）。
  static const double compactCardGradientOpacity = 0.68;

  static Color get glassBorderWhite => Colors.white.withValues(alpha: 0.2);

  static Color get glassFillLight => Colors.white.withValues(alpha: 0.55);

  /// 玻璃卡片大圓角（參考約 32–40）。
  static const double radiusGlassHero = 32;
  static const double radiusGlassCompact = 22;

  static const double blurSigmaCard = 24;
  /// 莫蘭迪彌散柔邊（過強會把多色糊成濁灰）。
  static const double blurSigmaMesh = 32;

  /// 漸層小卡字色（偏粉白）。
  static const Color onGradientPrimary = Color(0xFFFFF8FA);
  static const Color onGradientSecondary = Color(0xFFF0E0E8);
}

/// 首頁六張功能小卡：**粉嫩莫蘭迪漸層**（帶透明度以露出彌散底）。
abstract final class HomeCompactCardGradients {
  static LinearGradient _fill(Color a, Color b) {
    const o = HomeMeshReferenceColors.compactCardGradientOpacity;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        a.withValues(alpha: o),
        b.withValues(alpha: o),
      ],
    );
  }

  /// AI 相似題練習 — 蜜桃粉褐
  static LinearGradient get similarPractice => _fill(
        const Color(0xFFB89898),
        const Color(0xFFC8A8A8),
      );

  /// 錯題複習 — 藕粉紫
  static LinearGradient get review => _fill(
        const Color(0xFF9A7A98),
        const Color(0xFFA888A8),
      );

  /// 考試倒數 — 霧粉藍紫
  static LinearGradient get examCountdown => _fill(
        const Color(0xFF8A98B0),
        const Color(0xFF9AA0B8),
      );

  /// 自訂模擬測驗 — 玫瑰藕
  static LinearGradient get mockExam => _fill(
        const Color(0xFFB08888),
        const Color(0xFFC09898),
      );

  /// 知識圖譜 — 丁香粉紫
  static LinearGradient get knowledgeGraph => _fill(
        const Color(0xFF8E7898),
        const Color(0xFF9E88A8),
      );

  /// 學習儀表板 — 鼠尾藕粉綠
  static LinearGradient get learningDashboard => _fill(
        const Color(0xFF8FA090),
        const Color(0xFF9FB0A0),
      );
}

/// 首頁六張功能小卡順序（與 [HomeCompactCardGradients] 一致），內頁標題區可固定對應首頁入口色。
abstract final class HomeFeatureCardPaletteIndex {
  static const int similarPractice = 0;
  static const int review = 1;
  static const int examCountdown = 2;
  static const int mockExam = 3;
  static const int knowledgeGraph = 4;
  static const int learningDashboard = 5;
}

/// 與首頁六張功能小卡對應的**單色**（AI 相似題、錯題複習、考試倒數、模擬測驗、知識圖譜、學習儀表板）。
/// 用於標題卡背景、區塊內膠囊抽色等。
abstract final class HomeCompactCardPalette {
  static const List<Color> solidColors = <Color>[
    Color(0xFFB89898), // AI 相似題練習
    Color(0xFF9A7A98), // 錯題複習
    Color(0xFF8A98B0), // 考試倒數
    Color(0xFFB08888), // 自訂模擬測驗
    Color(0xFF8E7898), // 知識圖譜
    Color(0xFF8FA090), // 學習儀表板
  ];

  static Color colorForSeed(int seed) =>
      solidColors[seed.abs() % solidColors.length];

  /// 與 [solidColors] 同序：首頁六張功能小卡的**漸層**（與圖示一致，隨機選一張時請用此）。
  static LinearGradient compactGradientByIndex(int i) {
    switch (i % solidColors.length) {
      case 0:
        return HomeCompactCardGradients.similarPractice;
      case 1:
        return HomeCompactCardGradients.review;
      case 2:
        return HomeCompactCardGradients.examCountdown;
      case 3:
        return HomeCompactCardGradients.mockExam;
      case 4:
        return HomeCompactCardGradients.knowledgeGraph;
      case 5:
        return HomeCompactCardGradients.learningDashboard;
      default:
        return HomeCompactCardGradients.similarPractice;
    }
  }

  /// 同一區塊內第 [index] 顆膠囊：穩定偽隨機（不重排即可重現）。
  static Color chipColor({
    required int sectionIndex,
    required int index,
  }) =>
      colorForSeed(sectionIndex * 1009 + index * 97 + 13);

  /// 置於彩色底上的主文字（深淺自動）。
  static Color onAccent(Color background) =>
      background.computeLuminance() > 0.62
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFFFF8FA);

  static Color onAccentSecondary(Color background) =>
      background.computeLuminance() > 0.62
          ? const Color(0xFF666666)
          : Colors.white70;
}
