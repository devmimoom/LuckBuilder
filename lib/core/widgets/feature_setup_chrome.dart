import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/home_mesh_reference_colors.dart';

/// 與「自訂模擬測驗」設定頁一致：首頁六色漸層標題區。
class FeatureSetupHero extends StatelessWidget {
  const FeatureSetupHero({
    super.key,
    required this.paletteIndex,
    required this.title,
    required this.subtitle,
  });

  final int paletteIndex;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final i = paletteIndex % HomeCompactCardPalette.solidColors.length;
    final sample = HomeCompactCardPalette.solidColors[i];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: HomeCompactCardPalette.compactGradientByIndex(i),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: HomeCompactCardPalette.onAccent(sample),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              color: HomeCompactCardPalette.onAccentSecondary(sample),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// 區塊標題（與模擬測驗設定頁同字級）。
class FeatureSectionTitle extends StatelessWidget {
  const FeatureSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// 設定頁膠囊（與模擬測驗相同邏輯）。
class FeaturePaletteChipButton extends StatelessWidget {
  const FeaturePaletteChipButton({
    super.key,
    required this.sectionIndex,
    required this.chipIndex,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int sectionIndex;
  final int chipIndex;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = HomeCompactCardPalette.chipColor(
      sectionIndex: sectionIndex,
      index: chipIndex,
    );
    final fill = selected
        ? accent
        : Colors.white.withValues(alpha: 0.94);
    final fg = selected
        ? HomeCompactCardPalette.onAccent(accent)
        : Color.lerp(accent, const Color(0xFF2D2424), 0.55)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: accent,
            width: selected ? 2 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.38),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: selected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
