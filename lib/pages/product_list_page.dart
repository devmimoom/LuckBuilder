import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/v2_providers.dart';
import '../widgets/app_card.dart';
import '../theme/app_tokens.dart';
import '../theme/layout_constants.dart';
import 'product_page.dart';

class ProductListPage extends ConsumerWidget {
  final String topicId;
  const ProductListPage({super.key, required this.topicId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsByTopicProvider(topicId));
    final tokens = context.tokens;

    return Scaffold(
      appBar: AppBar(title: Text('Products · $topicId')),
      backgroundColor: tokens.bg,
      body: products.when(
        data: (ps) => ps.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No products in this topic',
                              style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          const SizedBox(height: 12),
                          Text('Topic ID: $topicId',
                              style: TextStyle(
                                  color: tokens.textSecondary, fontSize: 14)),
                          const SizedBox(height: 8),
                          Text('Query:',
                              style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('  • published = true',
                              style: TextStyle(
                                  color: tokens.textSecondary, fontSize: 12)),
                          Text('  • topicId = "$topicId"',
                              style: TextStyle(
                                  color: tokens.textSecondary, fontSize: 12)),
                          Text('  • orderBy(order)',
                              style: TextStyle(
                                  color: tokens.textSecondary, fontSize: 12)),
                          const SizedBox(height: 12),
                          Text(
                              'Check that Firestore products have topicId set to "$topicId".',
                              style: TextStyle(
                                  color: tokens.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = constraints.maxWidth;
                  final crossAxisCount = screenWidth > 500 ? 3 : 2;
                  const spacing = 12.0;
                  const gridPadding = 32.0; // EdgeInsets.all(16) 左右共 32
                  final cellWidth =
                      (screenWidth - gridPadding - (crossAxisCount - 1) * spacing) /
                          crossAxisCount;
                  final imageHeight = cellWidth / kCoverAspectRatio;
                  const textAreaHeight = 110.0;
                  final childAspectRatio =
                      cellWidth / (imageHeight + textAreaHeight);

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemCount: ps.length,
                    itemBuilder: (_, i) {
                      final p = ps[i];
                      return AppCard(
                        padding: EdgeInsets.zero,
                        onTap: () =>
                            Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ProductPage(productId: p.id),
                        )),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 封面圖片
                            if (p.coverImageUrl != null &&
                                p.coverImageUrl!.isNotEmpty)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20)),
                                child: AspectRatio(
                                  aspectRatio: kCoverAspectRatio,
                                  child: CachedNetworkImage(
                                    imageUrl: p.coverImageUrl!,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: tokens.chipBg,
                                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    ),
                                    errorWidget: (context, url, error) =>
                                            Container(
                                      color: tokens.chipBg,
                                      child: Icon(Icons.image_not_supported,
                                          color: tokens.textSecondary),
                                    ),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: tokens.textPrimary)),
                                    const SizedBox(height: 6),
                                    Text('${p.topicId} · ${p.level}',
                                        style: TextStyle(
                                            color: tokens.textSecondary)),
                                    const Spacer(),
                                    Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text('View ›',
                                            style: TextStyle(
                                                color: tokens.primary))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Load failed:',
                        style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(height: 12),
                    Text('Topic ID: $topicId',
                        style: TextStyle(
                            color: tokens.textSecondary, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('Error:',
                        style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '$err',
                      style:
                          TextStyle(color: tokens.textSecondary, fontSize: 12),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text('Query:',
                        style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('  • collection: products',
                        style: TextStyle(
                            color: tokens.textSecondary, fontSize: 12)),
                    Text('  • published = true',
                        style: TextStyle(
                            color: tokens.textSecondary, fontSize: 12)),
                    Text('  • topicId = "$topicId"',
                        style: TextStyle(
                            color: tokens.textSecondary, fontSize: 12)),
                    Text('  • orderBy(order)',
                        style: TextStyle(
                            color: tokens.textSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    Text('Possible causes:',
                        style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('  • Missing Firestore index',
                        style: TextStyle(
                            color: tokens.textSecondary, fontSize: 12)),
                    Text('  • Product documents missing topicId',
                        style: TextStyle(
                            color: tokens.textSecondary, fontSize: 12)),
                    Text('  • topicId value mismatch',
                        style: TextStyle(
                            color: tokens.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
