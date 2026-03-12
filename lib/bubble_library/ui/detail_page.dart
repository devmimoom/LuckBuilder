import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../models/user_library.dart';
import '../models/product.dart';
import '../models/content_item.dart';
import 'widgets/bubble_card.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_tokens.dart';
import '../../../providers/analytics_provider.dart';
import '../../../localization/app_language_provider.dart';
import '../../../localization/app_strings.dart';
import '../../notifications/favorite_sentences_store.dart';
import '../../services/learning_progress_service.dart';
import '../../../widgets/rich_sections/user_learning_store.dart';

class DetailPage extends ConsumerWidget {
  final String contentItemId;
  const DetailPage({super.key, required this.contentItemId});

  static final _loggedDetailIds = <String>{};

  List<Uri> _parseUrls(String s) {
    final parts = s.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty);
    final out = <Uri>[];
    for (final p in parts) {
      final u = Uri.tryParse(p);
      if (u != null && (u.scheme == 'http' || u.scheme == 'https')) out.add(u);
    }
    return out;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final itemAsync = ref.watch(contentItemProvider(contentItemId));
    final productsAsync = ref.watch(productsMapProvider);
    final savedAsync = ref.watch(savedItemsProvider);
    final tokens = context.tokens;

    if (itemAsync.hasValue && itemAsync.value != null && !_loggedDetailIds.contains(contentItemId)) {
      _loggedDetailIds.add(contentItemId);
      final item = itemAsync.value!;
      ref.read(analyticsProvider).logScreenView(screenName: 'detail');
      ref.read(analyticsProvider).logEvent('select_content', {
        'content_type': 'content',
        'item_id': contentItemId,
        'content_group': item.productId,
      });
    }

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        title: itemAsync.when(
          data: (item) => Text(
            item.displayAnchor(lang).isNotEmpty
                ? item.displayAnchor(lang)
                : uiString(lang, 'detail_title'),
            overflow: TextOverflow.ellipsis,
          ),
          loading: () => Text(uiString(lang, 'detail_title')),
          error: (_, __) => Text(uiString(lang, 'detail_title')),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: itemAsync.when(
        data: (item) {
          final urls = _parseUrls(item.sourceUrl);
          final productsMap = productsAsync.valueOrNull;
          final product = productsMap?[item.productId];
          final headerTitle = product?.displayTitle(lang) ?? item.displayAnchorGroup(lang);
          final headerSubtitle = [item.displayAnchor(lang), item.displayAnchorGroup(lang)]
              .where((s) => s.isNotEmpty)
              .join(' · ');

          return savedAsync.when(
            data: (savedMap) {
              final SavedContent? saved = savedMap[item.id];

              // 檢查是否登入
              String? uid;
              try {
                uid = ref.read(uidProvider);
              } catch (_) {
                return Center(
                  child: Text(uiString(lang, 'sign_in_to_use_feature')),
                );
              }

              final repo = ref.read(libraryRepoProvider);

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.sm),
                children: [
                  // 0) Header：主標=product.title，副標=anchor + anchorGroup
                  BubbleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(headerTitle,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: AppSpacing.xs),
                        Text(headerSubtitle,
                            style: TextStyle(color: tokens.textSecondary)),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _chip('intent：${item.displayIntent(lang)}'),
                            _chip('◆${item.difficulty}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // 1) 今日一句（移除「精華速讀」標題，直接顯示內容）
                  BubbleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.displayContent(lang),
                            style: const TextStyle(
                                fontSize: 18,
                                height: 1.35,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: item.displayContent(lang)));
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(uiString(lang, 'copied')),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 18),
                              label: Text(uiString(lang, 'copy')),
                            ),
                            Builder(
                              builder: (ctx) {
                                return TextButton.icon(
                                  onPressed: () async {
                                    final text = [
                                      headerTitle,
                                      headerSubtitle,
                                      '',
                                      item.displayContent(lang),
                                    ].join('\n');
                                    try {
                                      final box = ctx.findRenderObject() as RenderBox?;
                                      final origin = box != null
                                          ? box.localToGlobal(Offset.zero) & box.size
                                          : const Rect.fromLTWH(0, 0, 1, 1);
                                      await Share.share(
                                        text,
                                        subject: headerTitle,
                                        sharePositionOrigin: origin,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content:
                                                Text(uiString(lang, 'shared')),
                                          ),
                                        );
                                      }
                                    } catch (e, st) {
                                      debugPrint('Share: $e\n$st');
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${uiString(lang, 'share_not_available')}${e.toString()}',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.share, size: 18),
                                  label: Text(uiString(lang, 'share')),
                                );
                              },
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon((saved?.favorite ?? false)
                                  ? Icons.star
                                  : Icons.star_border),
                              onPressed: () async {
                                final newFavoriteState = !(saved?.favorite ?? false);
                                
                                // 更新 Firestore 的 favorite 欄位
                                await repo.setSavedItem(uid!, item.id,
                                    {'favorite': newFavoriteState});
                                
                                // 同時更新本地收藏的「今日一句」
                                if (newFavoriteState) {
                                  // 收藏：獲取產品名稱並保存到本地
                                  final productsMap = await ref.read(productsMapProvider.future);
                                  final product = productsMap[item.productId];
                                  final productName =
                                      product?.title ?? uiString(lang, 'unknown_product');
                                  
                                  await FavoriteSentencesStore.add(
                                    uid,
                                    FavoriteSentence(
                                      contentItemId: item.id,
                                      productId: item.productId,
                                      productName: productName,
                                      anchorGroup: item.anchorGroup,
                                      anchor: item.anchor,
                                      content: item.content,
                                      favoritedAt: DateTime.now(),
                                    ),
                                  );
                                } else {
                                  // 取消收藏：從本地移除
                                  await FavoriteSentencesStore.remove(uid, item.id);
                                }
                                
                                ref.invalidate(savedItemsProvider);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        // 獲取 product 和 topicId
                        final productsMap = await ref.read(productsMapProvider.future);
                        final product = productsMap[item.productId];
                        if (product == null) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  uiString(lang, 'could_not_load_product_info'),
                                ),
                              ),
                            );
                          }
                          return;
                        }
                        
                        // ✅ 先保底寫 saved_items（與 bootstrapper 一致）
                        // 避免 markLearnedAndAdvance 的 early return 跳過 saved_items 寫入
                        try {
                          await repo.setSavedItem(uid!, item.id, {'learned': true});
                        } catch (e) {
                          debugPrint('⚠️ setSavedItem fallback error: $e');
                        }

                        final progress = LearningProgressService();
                        try {
                          await progress.markLearnedAndAdvance(
                            topicId: product.topicId,
                            contentId: item.id,
                            pushOrder: item.pushOrder,
                            source: 'detail_page',
                          );
                        } catch (e) {
                          // 已有 setSavedItem 保底，忽略即可
                          debugPrint('⚠️ markLearnedAndAdvance failed (fallback used): $e');
                        }
                        ref.read(analyticsProvider).logEvent('mark_learned', {
                          'content_id': item.id,
                          'topic_id': product.topicId,
                        });
                        // 以「標記學會」為準：更新 streak（當天有學習）
                        await UserLearningStore().markLearnedTodayAndGlobal(item.productId);
                        ref.invalidate(savedItemsProvider);
                        ref.invalidate(libraryProductsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text(uiString(lang, 'marked_as_complete')),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: Text(uiString(lang, 'done')),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // 2) 深度解析（Excel deepAnalysis 欄位）
                  BubbleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          uiString(lang, 'deep_dive'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        if (item.displayDeepAnalysis(lang).isEmpty)
                          Text(
                            uiString(lang, 'no_content'),
                            style: TextStyle(color: tokens.textSecondary),
                          )
                        else
                          Text(item.displayDeepAnalysis(lang),
                              style: const TextStyle(
                                  height: 1.35,
                                  fontSize: 15)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // 3) 延伸閱讀
                  BubbleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          uiString(lang, 'further_reading'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        if (urls.isEmpty)
                          Text(
                            uiString(lang, 'no_links'),
                            style: TextStyle(color: tokens.textSecondary),
                          )
                        else
                          ...urls.map((u) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: () async {
                                    if (await canLaunchUrl(u)) {
                                      await launchUrl(u,
                                          mode: LaunchMode.externalApplication);
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              uiString(
                                                  lang, 'could_not_open_link'),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Text(u.toString(),
                                      style: const TextStyle(
                                          decoration:
                                              TextDecoration.underline)),
                                ),
                              )),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('${uiString(lang, 'saved_error')}$e'),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('${uiString(lang, 'detail_error')}$e'),
        ),
      ),
    );
  }

  Widget _chip(String text) => Builder(
        builder: (context) {
          final tokens = context.tokens;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              gradient: tokens.chipGradient,
              color: tokens.chipGradient == null ? tokens.chipBg : null,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: tokens.cardBorder),
            ),
            child: Text(
              text,
              style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          );
        },
      );
}
