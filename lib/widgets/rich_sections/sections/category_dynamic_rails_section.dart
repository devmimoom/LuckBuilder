import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/v2_providers.dart';
import '../../../theme/app_tokens.dart';
import '../../../theme/layout_constants.dart';
import '../../app_card.dart';
import '../../../data/models.dart';
import '../../../pages/product_page.dart';

class CategoryDynamicRailsSection extends ConsumerWidget {
  const CategoryDynamicRailsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;

    final segsAsync = ref.watch(segmentsProvider);
    final selected = ref.watch(selectedSegmentProvider);

    return segsAsync.when(
      data: (segs) {
        // 取目前 segment（若尚未選，fallback 第一個）
        final seg = selected ?? (segs.isNotEmpty ? segs.first : null);

        // 依 segment 做 listId（你之後 Firestore 用這些 id 建 featured_lists 文件）
        final segId = seg?.id ?? 'all';
        final newId = 'cat_new_$segId';
        final hotId = 'cat_hot_$segId';
        final forYouId = 'cat_for_you_$segId';

        final newAsync = ref.watch(featuredProductsProvider(newId));
        final hotAsync = ref.watch(featuredProductsProvider(hotId));
        final forYouAsync = ref.watch(featuredProductsProvider(forYouId));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'For you',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _RailBlock(
              title: 'For you',
              async: forYouAsync,
              emptyHint: 'No data (check Firestore featured_lists/$forYouId)',
            ),
            const SizedBox(height: 14),
            _RailBlock(
              title: 'New',
              async: newAsync,
              emptyHint: 'No data (check Firestore featured_lists/$newId)',
            ),
            const SizedBox(height: 14),
            _RailBlock(
              title: 'Popular',
              async: hotAsync,
              emptyHint: 'No data (check Firestore featured_lists/$hotId)',
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('CategoryDynamicRailsSection error: $e',
              style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}

class _RailBlock extends StatelessWidget {
  final String title;
  final AsyncValue<List<Product>> async;
  final String emptyHint;

  const _RailBlock({
    required this.title,
    required this.async,
    required this.emptyHint,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth * 0.55).clamp(180.0, kMaxSmallCardWidth);
    final imageHeight = cardWidth / kCoverAspectRatio;
    const textArea = 78.0; // 原 170-92
    final railHeight = imageHeight + textArea;

    return async.when(
      data: (ps) {
        if (ps.isEmpty) {
          return AppCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(emptyHint,
                  style: TextStyle(color: tokens.textSecondary)),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('│ $title',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: tokens.textPrimary,
                )),
            const SizedBox(height: 10),
            SizedBox(
              height: railHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ps.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final p = ps[i];
                  return _MiniProductCard(
                    product: p,
                    cardWidth: cardWidth,
                    imageHeight: imageHeight,
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => SizedBox(
        height: railHeight,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text('$title error: $e',
              style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}

class _MiniProductCard extends StatelessWidget {
  final Product product;
  final double cardWidth;
  final double imageHeight;
  const _MiniProductCard({
    required this.product,
    required this.cardWidth,
    required this.imageHeight,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SizedBox(
      width: cardWidth,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProductPage(productId: product.id)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // cover
            if (product.coverImageUrl != null &&
                product.coverImageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: CachedNetworkImage(
                  imageUrl: product.coverImageUrl!,
                  width: double.infinity,
                  height: imageHeight,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: imageHeight,
                    color: tokens.chipBg,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: imageHeight,
                    color: tokens.chipBg,
                    child: Icon(Icons.image_not_supported,
                        color: tokens.textSecondary),
                  ),
                ),
              )
            else
              Container(
                height: imageHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: tokens.chipBg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Icon(Icons.auto_awesome, color: tokens.textSecondary),
              ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${product.topicId} · ${product.level}',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                  ),
                  if (product.levelGoal != null &&
                      product.levelGoal!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      product.levelGoal!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: tokens.textSecondary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
