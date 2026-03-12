import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app_card.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_tokens.dart';
import '../../../theme/layout_constants.dart';
import '../../../localization/app_language.dart';
import '../../../localization/app_strings.dart';

class LibraryRichCard extends StatelessWidget {
  final String title;
  final String? coverImageUrl;

  // 三個資訊：總內容數 / 推播排程 / 下一則內容
  final int? totalItems; // 共 XX 則
  final String? level; // e.g. Foundation, L1；與 items 同一行顯示
  final String nextPushText; // e.g. 每週一三五 08:30 / 下一則 10:30
  final String latestTitle; // e.g. 最近：黑洞是什麼？

  // 右上角操作（⋯ 選單）
  final Widget? headerTrailing;

  final VoidCallback? onLearnNow;
  final VoidCallback? onMakeUpToday;
  final VoidCallback? onPreview3Days;
  final VoidCallback? onTap;

  final AppLanguage? lang;

  const LibraryRichCard({
    super.key,
    required this.title,
    this.coverImageUrl,
    this.totalItems,
    this.level,
    required this.nextPushText,
    required this.latestTitle,
    this.headerTrailing,
    this.onLearnNow,
    this.onMakeUpToday,
    this.onPreview3Days,
    this.onTap,
    this.lang,
  });

  static String _levelDisplayName(String level, AppLanguage lang) {
    final k = level.toLowerCase().replaceAll(' ', '_');
    if (k.contains('foundation')) return uiString(lang, 'level_foundation');
    if (k.contains('practical')) return uiString(lang, 'level_practical');
    if (k.contains('deep')) return uiString(lang, 'level_deep_dive');
    if (k.contains('specialized')) return uiString(lang, 'level_specialized');
    return level;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面（有就顯示）
          if (coverImageUrl != null && coverImageUrl!.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final h = (constraints.maxWidth / kCoverAspectRatio)
                    .clamp(120.0, 260.0);
                return ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusMd)),
                  child: CachedNetworkImage(
                    imageUrl: coverImageUrl!,
                    height: h,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: h,
                      color: tokens.chipBg,
                      alignment: Alignment.center,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: h,
                      color: tokens.chipBg,
                      alignment: Alignment.center,
                      child: Icon(Icons.image_not_supported,
                          color: tokens.textSecondary),
                    ),
                  ),
                );
              },
            ),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: tokens.textPrimary),
                          ),
                          if (totalItems != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              lang != null
                                  ? (level != null && level!.isNotEmpty
                                      ? uiString(lang!, 'items_and_level')
                                          .replaceFirst('{n}', '$totalItems')
                                          .replaceFirst('{level}', _levelDisplayName(level!, lang!))
                                      : uiString(lang!, 'items_only').replaceFirst('{n}', '$totalItems'))
                                  : (level != null && level!.isNotEmpty
                                      ? '$totalItems items · $level'
                                      : '$totalItems items'),
                              style: TextStyle(
                                fontSize: 12,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (headerTrailing != null) ...[
                      const SizedBox(width: 8),
                      headerTrailing!,
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                // 兩個資訊（推播排程 / 下一則內容）
                _InfoRow(icon: Icons.schedule, text: nextPushText),
                const SizedBox(height: AppSpacing.xs),
                _InfoRow(icon: Icons.notes, text: latestTitle),

              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        Icon(icon, size: 18, color: tokens.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.textSecondary),
          ),
        ),
      ],
    );
  }
}
