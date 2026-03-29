import 'package:flutter/material.dart';

import 'home_mesh_reference_colors.dart';

/// 首頁彌散背景預設（漸層三色 + 四類色團基底 + 設定頁預覽色）。
class HomeBackgroundPreset {
  const HomeBackgroundPreset({
    required this.id,
    required this.label,
    required this.gradientTop,
    required this.gradientMid,
    required this.gradientBottom,
    required this.blobTeal,
    required this.blobLavender,
    required this.blobPeach,
    required this.blobPinkMist,
    required this.previewColor,
  });

  final HomeBackgroundPresetId id;
  final String label;
  final Color gradientTop;
  final Color gradientMid;
  final Color gradientBottom;
  final Color blobTeal;
  final Color blobLavender;
  final Color blobPeach;
  final Color blobPinkMist;
  /// 設定頁小圓圈示意色。
  final Color previewColor;
}

enum HomeBackgroundPresetId {
  pinkMist,
  dreamyBright,
  morandiCool,
  warmSand,
  oceanBlue,
  lilacPurple,
  meadowGreen,
  midnightBlack,
  paperWhite,
  coffeeBrown,
}

/// 內建預設組與查表。
abstract final class HomeBackgroundPresets {
  /// 預設：藕粉霧（較明顯的粉調；色團僅此主題使用，不影響其他頁全域色票）。
  static const HomeBackgroundPreset pinkMist = HomeBackgroundPreset(
    id: HomeBackgroundPresetId.pinkMist,
    label: '藕粉霧',
    gradientTop: HomeMeshReferenceColors.meshBaseTop,
    gradientMid: HomeMeshReferenceColors.meshBaseMid,
    gradientBottom: Color(0xFFFFDEE8),
    blobTeal: Color(0xFFC8A8B4),
    blobLavender: Color(0xFFD8A0C0),
    blobPeach: Color(0xFFE8A8B8),
    blobPinkMist: Color(0xFFF0A0BC),
    previewColor: Color(0xFFF0A0B8),
  );

  /// 亮色系：天藍／奶油／淡底。
  static const HomeBackgroundPreset dreamyBright = HomeBackgroundPreset(
    id: HomeBackgroundPresetId.dreamyBright,
    label: '晴空奶油',
    gradientTop: Color(0xFFC0E3F5),
    gradientMid: Color(0xFFFCF5D2),
    gradientBottom: Color(0xFFFAF0F5),
    blobTeal: Color(0xFF7EC8E3),
    blobLavender: Color(0xFFB8C5E8),
    blobPeach: Color(0xFFECD9A8),
    blobPinkMist: Color(0xFFEDD0E0),
    previewColor: Color(0xFFFFEC8E),
  );

  /// 冷灰莫蘭迪。
  static const HomeBackgroundPreset morandiCool = HomeBackgroundPreset(
    id: HomeBackgroundPresetId.morandiCool,
    label: '霧灰藍',
    gradientTop: Color(0xFFECEFF3),
    gradientMid: Color(0xFFF0EEEC),
    gradientBottom: Color(0xFFF7F5F4),
    blobTeal: Color(0xFFA8B4B8),
    blobLavender: Color(0xFFB4B0BC),
    blobPeach: Color(0xFFC0B8B0),
    blobPinkMist: Color(0xFFD4CCD0),
    previewColor: Color(0xFF9BA8B8),
  );

  /// 暖沙杏色。
  static const HomeBackgroundPreset warmSand = HomeBackgroundPreset(
    id: HomeBackgroundPresetId.warmSand,
    label: '暖沙杏',
    gradientTop: Color(0xFFF5E8DC),
    gradientMid: Color(0xFFF0E0D4),
    gradientBottom: Color(0xFFFAF4EF),
    blobTeal: Color(0xFFC4B5A0),
    blobLavender: Color(0xFFD4B8B0),
    blobPeach: Color(0xFFE8C4A8),
    blobPinkMist: Color(0xFFE8D0C8),
    previewColor: Color(0xFFE8A87C),
  );

  /// 藍色系：霧藍天光。
  static const HomeBackgroundPreset oceanBlue = HomeBackgroundPreset(
    id: HomeBackgroundPresetId.oceanBlue,
    label: '藍色',
    gradientTop: Color(0xFFD6EAF8),
    gradientMid: Color(0xFFE3F2FD),
    gradientBottom: Color(0xFFF5FAFE),
    blobTeal: Color(0xFF5DADE2),
    blobLavender: Color(0xFF85C1E9),
    blobPeach: Color(0xFFAED6F1),
    blobPinkMist: Color(0xFFB8D4F0),
    previewColor: Color(0xFF42A5F5),
  );

  /// 紫色系：藕荷霧紫。
  static const HomeBackgroundPreset lilacPurple = HomeBackgroundPreset(
    id: HomeBackgroundPresetId.lilacPurple,
    label: '紫色',
    gradientTop: Color(0xFFEDE7F6),
    gradientMid: Color(0xFFF3E5F5),
    gradientBottom: Color(0xFFFAF5FF),
    blobTeal: Color(0xFFB39DDB),
    blobLavender: Color(0xFFCE93D8),
    blobPeach: Color(0xFFE1BEE7),
    blobPinkMist: Color(0xFFF8BBD9),
    previewColor: Color(0xFFAB47BC),
  );

  /// 綠色系：薄荷霧綠。
  static const HomeBackgroundPreset meadowGreen = HomeBackgroundPreset(
    id: HomeBackgroundPresetId.meadowGreen,
    label: '綠色',
    gradientTop: Color(0xFFE0F2E8),
    gradientMid: Color(0xFFE8F5E9),
    gradientBottom: Color(0xFFF5FBF6),
    blobTeal: Color(0xFF81C784),
    blobLavender: Color(0xFFA5D6A7),
    blobPeach: Color(0xFFC8E6C9),
    blobPinkMist: Color(0xFFB2DFDB),
    previewColor: Color(0xFF66BB6A),
  );

  /// 深灰系：深灰漸層＋米白／咖啡色團（設定頁原「黑色」選項）。
  static const HomeBackgroundPreset midnightBlack = HomeBackgroundPreset(
    id: HomeBackgroundPresetId.midnightBlack,
    label: '深灰',
    gradientTop: Color(0xFF34353A),
    gradientMid: Color(0xFF3C3D44),
    gradientBottom: Color(0xFF44464E),
    blobTeal: Color(0xFFF2F0EC),
    blobLavender: Color(0xFF5C4A3E),
    blobPeach: Color(0xFF8B6F5C),
    blobPinkMist: Color(0xFFEDE8E0),
    previewColor: Color(0xFF544F4A),
  );

  /// 白色系：淺灰白漸層＋柔霧色團。
  static const HomeBackgroundPreset paperWhite = HomeBackgroundPreset(
    id: HomeBackgroundPresetId.paperWhite,
    label: '白色',
    gradientTop: Color(0xFFFCFCFE),
    gradientMid: Color(0xFFF8F8FA),
    gradientBottom: Color(0xFFF2F2F6),
    blobTeal: Color(0xFFFFFFFF),
    blobLavender: Color(0xFFF0EEF5),
    blobPeach: Color(0xFFEAE8F0),
    blobPinkMist: Color(0xFFE4E2EC),
    previewColor: Color(0xFFE8E8EE),
  );

  /// 咖啡色系：暖褐漸層＋拿鐵／焦糖色團。
  static const HomeBackgroundPreset coffeeBrown = HomeBackgroundPreset(
    id: HomeBackgroundPresetId.coffeeBrown,
    label: '咖啡色',
    gradientTop: Color(0xFF4A3D36),
    gradientMid: Color(0xFF3D332E),
    gradientBottom: Color(0xFF322A26),
    blobTeal: Color(0xFFB89A82),
    blobLavender: Color(0xFF8B6F5C),
    blobPeach: Color(0xFF6B5344),
    blobPinkMist: Color(0xFFA8896E),
    previewColor: Color(0xFF5D4037),
  );

  static const List<HomeBackgroundPreset> all = [
    pinkMist,
    dreamyBright,
    morandiCool,
    warmSand,
    oceanBlue,
    lilacPurple,
    meadowGreen,
    midnightBlack,
    paperWhite,
    coffeeBrown,
  ];

  static HomeBackgroundPreset get defaultPreset => pinkMist;

  static HomeBackgroundPreset byId(HomeBackgroundPresetId id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return defaultPreset;
  }

  static HomeBackgroundPreset? tryParseId(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final id in HomeBackgroundPresetId.values) {
      if (id.name == name) return byId(id);
    }
    return null;
  }
}
