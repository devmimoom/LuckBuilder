import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/v2_providers.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../data/models.dart';
import '../widgets/rich_sections/sections/category_netflix_rails_section.dart';
import 'product_list_page.dart';
import '../localization/app_language.dart';
import '../localization/app_language_provider.dart';
import '../localization/app_strings.dart';

// 預設漸層色盤（依 index % length 取用）
const _kGradients = [
  [Color(0xFFFF6B35), Color(0xFFE63946)],
  [Color(0xFF2D00F7), Color(0xFF8900F2)],
  [Color(0xFF00B4D8), Color(0xFF03045E)],
  [Color(0xFF10002B), Color(0xFF7B2FBE)],
  [Color(0xFF2B2D42), Color(0xFF8D99AE)],
  [Color(0xFF370617), Color(0xFFE85D04)],
  [Color(0xFFFF9F1C), Color(0xFFCB4335)],
  [Color(0xFF184E77), Color(0xFF168AAD)],
];

// Segment 標題 -> emoji（無則空字串）
final _segmentEmoji = <String, String>{
  'Life': '🌿',
  'Health': '❤️',
  'Growth': '🚀',
  'Work': '💼',
  'Mind': '🧠',
};

// Topic 標題 -> emoji（無則用標題首字）
final _topicEmoji = <String, String>{
  'Emotion': '🌊',
  'Focus': '💫',
  'Habits': '🔄',
  'Sleep': '🌙',
  'Minimalism': '⚫',
  'Stress': '⚡',
  'Home': '🏠',
  'Time': '⏳',
};

String _emojiForTopic(Topic t) {
  return _topicEmoji[t.title] ?? (t.title.isNotEmpty ? t.title[0] : '•');
}

/// Embeddable section: Explore header, segment chips, topic grid, Netflix rails.
class ExploreSection extends ConsumerWidget {
  const ExploreSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final segs = ref.watch(segmentsProvider);
    final selected = ref.watch(selectedSegmentProvider);
    final topicsAsync = ref.watch(topicsForSelectedSegmentProvider);

    final lang = ref.watch(appLanguageProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context, ref, topicsAsync, tokens),
        _buildChips(context, ref, segs, selected, tokens, lang),
        _buildGrid(context, ref, topicsAsync, tokens, lang),
        const CategoryNetflixRailsSection(),
        const SizedBox(height: 24),
      ],
    );
  }
}

Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Topic>> topicsAsync,
    AppTokens tokens,
  ) {
    return topicsAsync.when(
      data: (ts) {
        int totalCards = 0;
        for (final t in ts) {
          final products = ref.watch(productsByTopicProvider(t.id));
          totalCards += products.maybeWhen(
            data: (list) => list.length,
            orElse: () => 0,
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Explore',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${ts.length} topics · $totalCards cards',
                  textAlign: TextAlign.left,
                  style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Explore',
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '— topics · — cards',
                textAlign: TextAlign.left,
                style: TextStyle(color: tokens.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            'Explore',
            textAlign: TextAlign.left,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

Widget _buildChips(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Segment>> segs,
    Segment? selected,
    AppTokens tokens,
    AppLanguage lang,
  ) {
    return segs.when(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final selectedId = selected?.id ?? list.first.id;
        return SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final s = list[i];
              final active = s.id == selectedId;
              final displayTitle = s.displayTitle(lang);
              final emoji = _segmentEmoji[s.title] ?? '';
              final label = emoji.isEmpty ? displayTitle : '$emoji  $displayTitle';
              return GestureDetector(
                onTap: () =>
                    ref.read(selectedSegmentProvider.notifier).state = s,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: active
                        ? tokens.primary.withValues(alpha: 0.12)
                        : tokens.chipBg,
                    borderRadius: BorderRadius.circular(48),
                    border: Border.all(
                      color: active
                          ? tokens.primary.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.08),
                      width: active ? 1.5 : 1,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: tokens.primary.withValues(alpha: 0.2),
                              blurRadius: 8,
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: active ? tokens.primary : tokens.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(height: 48),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

const _kGridPadding = AppSpacing.md;
const _kGridGap = 8.0;

Widget _buildGrid(
  BuildContext context,
  WidgetRef ref,
  AsyncValue<List<Topic>> topicsAsync,
  AppTokens tokens,
  AppLanguage lang,
) {
    return topicsAsync.when(
      data: (ts) {
        if (ts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: tokens.cardBg,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: tokens.cardBorder),
              ),
              child: Center(
                child: Text(
                  uiString(lang, 'explore_no_topics'),
                  style: TextStyle(color: tokens.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        final contentWidth =
            MediaQuery.sizeOf(context).width - (_kGridPadding * 2);
        // Bento: 大卡 = 2*小卡 + gap，一列 = 大卡 + gap + 小卡
        final smallSize = (contentWidth - 2 * _kGridGap) / 3;
        final largeSize = 2 * smallSize + _kGridGap;

        final rows = <Widget>[];
        var i = 0;
        var chunkIndex = 0;

        while (i < ts.length) {
          final remaining = ts.length - i;

          if (remaining >= 3) {
            final a = ts[i];
            final b = ts[i + 1];
            final c = ts[i + 2];
            final leftLarge = chunkIndex.isEven;

            final largeCard = SizedBox(
              width: largeSize,
              height: largeSize,
              child: _CategoryCard(
                topic: a,
                index: i,
                size: largeSize,
              ),
            );

            final smallCards = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: smallSize,
                  height: smallSize,
                  child: _CategoryCard(topic: b, index: i + 1, size: smallSize),
                ),
                const SizedBox(height: _kGridGap),
                SizedBox(
                  width: smallSize,
                  height: smallSize,
                  child: _CategoryCard(topic: c, index: i + 2, size: smallSize),
                ),
              ],
            );

            rows.add(
              Padding(
                padding: const EdgeInsets.only(bottom: _kGridGap),
                child: SizedBox(
                  height: largeSize,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: leftLarge
                        ? [
                            largeCard,
                            const SizedBox(width: _kGridGap),
                            smallCards,
                          ]
                        : [
                            smallCards,
                            const SizedBox(width: _kGridGap),
                            largeCard,
                          ],
                  ),
                ),
              ),
            );

            i += 3;
            chunkIndex++;
          } else {
            // 尾巴：不足 3 個，均分一列正方形
            final rem = ts.sublist(i);
            final evenSize = rem.length == 1
                ? contentWidth
                : (contentWidth - _kGridGap * (rem.length - 1)) / rem.length;

            rows.add(
              Padding(
                padding: const EdgeInsets.only(bottom: _kGridGap),
                child: SizedBox(
                  height: evenSize,
                  child: Row(
                    children: [
                      for (var j = 0; j < rem.length; j++) ...[
                        if (j > 0) const SizedBox(width: _kGridGap),
                        SizedBox(
                          width: evenSize,
                          height: evenSize,
                          child: _CategoryCard(
                            topic: rem[j],
                            index: i + j,
                            size: evenSize,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
            break;
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(_kGridPadding, 16, _kGridPadding, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: rows,
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.cardBg,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: tokens.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(uiString(ref.read(appLanguageProvider), 'topics_error_title'),
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.xs),
              Text('$err',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

class _CategoryCard extends ConsumerWidget {
  final Topic topic;
  final int index;
  final double size;

  const _CategoryCard({
    required this.topic,
    required this.index,
    required this.size,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final productsAsync = ref.watch(productsByTopicProvider(topic.id));
    final cardCount = productsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );
    final gradient = _kGradients[index % _kGradients.length];
    final emoji = _emojiForTopic(topic);
    final hasImage = topic.bubbleImageUrl != null &&
        topic.bubbleImageUrl!.isNotEmpty;
    final isLarge = size > 120;
    final titleFontSize = isLarge ? 15.0 : 12.0;
    final subtitleFontSize = isLarge ? 10.0 : 9.0;
    final emojiFontSize = isLarge ? 42.0 : 28.0;
    final bottomPadding = isLarge ? 16.0 : 8.0;
    final leftPadding = isLarge ? 16.0 : 8.0;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => ProductListPage(topicId: topic.id)),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                CachedNetworkImage(
                  imageUrl: topic.bubbleImageUrl!,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  placeholder: (_, __) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              if (!hasImage)
                Positioned(
                  top: size * 0.15,
                  left: 0,
                  right: 0,
                  child: Text(
                    emoji,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: emojiFontSize),
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.72),
                      ],
                      stops: const [0.3, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: bottomPadding,
                left: leftPadding,
                right: leftPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      topic.displayTitle(lang),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        shadows: const [
                          Shadow(blurRadius: 8, color: Colors.black54),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '$cardCount cards',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: subtitleFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

