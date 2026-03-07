import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/v2_providers.dart';
import '../widgets/app_card.dart';
import '../theme/app_tokens.dart';
import '../theme/layout_constants.dart';
import '../localization/app_language_provider.dart';
import '../localization/app_strings.dart';
import '../localization/bilingual_text.dart';
import 'product_page.dart';

class ProductListPage extends ConsumerWidget {
  /// 依主題列出產品（與 productIds 二選一）
  final String? topicId;
  /// 依 ID 列表列出產品（與 topicId 二選一）；用於橫幅等多產品入口
  final List<String>? productIds;
  /// 列表頁標題；依 productIds 時使用，依 topicId 時可選
  final String? title;

  ProductListPage({
    super.key,
    this.topicId,
    this.productIds,
    this.title,
  }) : assert(
          (topicId != null && (productIds == null || productIds.isEmpty)) ||
              (productIds != null && productIds.isNotEmpty && topicId == null),
          'Provide exactly one of topicId or non-empty productIds',
        );

  bool get _byIds {
    final ids = productIds;
    return ids != null && ids.isNotEmpty;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = _byIds
        ? ref.watch(productsByIdsProvider(productIds!.join(';')))
        : ref.watch(productsByTopicProvider(topicId!));
    final tokens = context.tokens;
    final lang = ref.watch(appLanguageProvider);
    final appBarTitle = _byIds
        ? (title ?? 'Products')
        : (title ?? 'Products · $topicId');

    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle)),
      backgroundColor: tokens.bg,
      body: productsAsync.when(
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
                          Text(
                              _byIds
                                  ? 'No products'
                                  : 'No products in this topic',
                              style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          if (!_byIds) ...[
                            const SizedBox(height: 12),
                            Text('${uiString(lang, 'topic_id_label')}$topicId',
                                style: TextStyle(
                                    color: tokens.textSecondary, fontSize: 14)),
                            const SizedBox(height: 8),
                            Text(uiString(lang, 'query_label'),
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
                  const textAreaHeight = 80.0;
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
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(productTitle(p, lang),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: tokens.textPrimary)),
                                    const SizedBox(height: 4),
                                    Text('${p.topicId} · ${p.level}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: tokens.textSecondary)),
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
                    Text(uiString(lang, 'load_failed'),
                        style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(height: 12),
                    if (!_byIds)
                      Text('${uiString(lang, 'topic_id_label')}$topicId',
                          style: TextStyle(
                              color: tokens.textSecondary, fontSize: 14)),
                    if (!_byIds) const SizedBox(height: 8),
                    Text(uiString(lang, 'error_label'),
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
                    if (!_byIds) ...[
                      const SizedBox(height: 8),
                      Text(uiString(lang, 'query_label'),
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
                      Text(uiString(lang, 'possible_causes'),
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
