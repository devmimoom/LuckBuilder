import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/home_background_preset.dart';
import '../../../core/widgets/premium_card.dart';
import '../providers/home_background_preset_provider.dart';

final Future<PackageInfo> _packageInfoFuture = PackageInfo.fromPlatform();

/// App 設定與關於資訊（版本號等）。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const String _appDisplayName = '錯題解析助手';

  static const _pickerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF2DD4BF),
      Color(0xFF22D3EE),
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPreset = ref.watch(homeBackgroundPresetProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          Text(
            '首頁背景',
            style: AppFonts.resolve(
              const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFonts.sizeCaption,
                fontWeight: AppFonts.weightSemibold,
                letterSpacing: AppFonts.letterSpacingTitle,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              gradient: _pickerGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < HomeBackgroundPresets.all.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    _BackgroundSwatch(
                      preset: HomeBackgroundPresets.all[i],
                      selected:
                          selectedPreset.id == HomeBackgroundPresets.all[i].id,
                      onTap: () => ref
                          .read(homeBackgroundPresetProvider.notifier)
                          .select(HomeBackgroundPresets.all[i].id),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            '關於',
            style: AppFonts.resolve(
              const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFonts.sizeCaption,
                fontWeight: AppFonts.weightSemibold,
                letterSpacing: AppFonts.letterSpacingTitle,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PremiumCard(
            padding: AppSpacing.cardPaddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _appDisplayName,
                  style: AppFonts.resolve(
                    const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppFonts.sizeTitleLg,
                      fontWeight: AppFonts.weightSemibold,
                      height: AppFonts.lineHeightTight,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '整理錯題、複習與練習，讓準備考試更有方向。',
                  style: AppFonts.resolve(
                    const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFonts.sizeBodyLg,
                      height: AppFonts.lineHeightBody,
                      fontWeight: AppFonts.weightRegular,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Text(
                      '版本',
                      style: AppFonts.resolve(
                        const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppFonts.sizeBodySm,
                          fontWeight: AppFonts.weightRegular,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FutureBuilder<PackageInfo>(
                        future: _packageInfoFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accent,
                                ),
                              ),
                            );
                          }
                          if (snapshot.hasError || !snapshot.hasData) {
                            return Text(
                              '無法讀取版本',
                              style: AppFonts.resolve(
                                const TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: AppFonts.sizeBodySm,
                                  fontWeight: AppFonts.weightRegular,
                                ),
                              ),
                            );
                          }
                          final info = snapshot.data!;
                          return Text(
                            '${info.version} (${info.buildNumber})',
                            style: AppFonts.resolve(
                              const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: AppFonts.sizeBodySm,
                                fontWeight: AppFonts.weightMedium,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundSwatch extends StatelessWidget {
  const _BackgroundSwatch({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final HomeBackgroundPreset preset;
  final bool selected;
  final VoidCallback onTap;

  static const double _sizeNormal = 40;
  static const double _sizeSelected = 50;

  @override
  Widget build(BuildContext context) {
    final size = selected ? _sizeSelected : _sizeNormal;
    return Semantics(
      label: preset.label,
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: preset.previewColor,
              border: Border.all(
                color: Colors.white,
                width: selected ? 3 : 1.5,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
