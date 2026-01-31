import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../models/user_library.dart';
import 'widgets/bubble_card.dart';
import '../../../theme/app_tokens.dart';
import '../../notifications/favorite_sentences_store.dart';
import '../../services/learning_progress_service.dart';

class DetailPage extends ConsumerWidget {
  final String contentItemId;
  const DetailPage({super.key, required this.contentItemId});

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
    final itemAsync = ref.watch(contentItemProvider(contentItemId));
    final productsAsync = ref.watch(productsMapProvider);
    final savedAsync = ref.watch(savedItemsProvider);
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        title: itemAsync.when(
          data: (item) => Text(
            item.anchor.isNotEmpty ? item.anchor : 'Detail',
            overflow: TextOverflow.ellipsis,
          ),
          loading: () => const Text('Detail'),
          error: (_, __) => const Text('Detail'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: itemAsync.when(
        data: (item) {
          final urls = _parseUrls(item.sourceUrl);
          final productsMap = productsAsync.valueOrNull;
          final product = productsMap?[item.productId];
          final headerTitle = product?.title ?? item.anchorGroup;
          final headerSubtitle = [item.anchor, item.anchorGroup]
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
                return const Center(child: Text('Sign in to use this feature.'));
              }

              final repo = ref.read(libraryRepoProvider);

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // 0) Header：主標=product.title，副標=anchor + anchorGroup
                  BubbleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(headerTitle,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(headerSubtitle,
                            style: TextStyle(color: tokens.textSecondary)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _chip('intent：${item.intent}'),
                            _chip('◆${item.difficulty}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 1) 今日一句
                  BubbleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Key idea',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Text(item.content,
                            style: const TextStyle(
                                fontSize: 18,
                                height: 1.35,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: item.content));
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Copied.')));
                              },
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('Copy'),
                            ),
                            Builder(
                              builder: (ctx) {
                                return TextButton.icon(
                                  onPressed: () async {
                                    final text = [
                                      headerTitle,
                                      headerSubtitle,
                                      '',
                                      item.content,
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
                                            const SnackBar(content: Text('Shared.')));
                                      }
                                    } catch (e, st) {
                                      debugPrint('Share: $e\n$st');
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Share not available: ${e.toString()}')));
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.share, size: 18),
                                  label: const Text('Share'),
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
                                  final productName = product?.title ?? 'Unknown product';
                                  
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
                  const SizedBox(height: 12),

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
                              const SnackBar(content: Text('Could not load product info.')),
                            );
                          }
                          return;
                        }
                        
                        final progress = LearningProgressService();
                        try {
                          await progress.markLearnedAndAdvance(
                            topicId: product.topicId,
                            contentId: item.id,
                            pushOrder: item.pushOrder,
                            source: 'detail_page',
                          );
                          // ✅ 刷新 UI（savedItemsProvider 是 StreamProvider，會自動更新）
                          // 但為確保即時性，手動 invalidate
                          ref.invalidate(savedItemsProvider);
                          ref.invalidate(libraryProductsProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Marked as complete.')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Action failed: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Done'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2) 深度解析（Excel deepAnalysis 欄位）
                  BubbleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Deep dive',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        if (item.deepAnalysis.isEmpty)
                          Text('No content',
                              style: TextStyle(color: tokens.textSecondary))
                        else
                          Text(item.deepAnalysis,
                              style: const TextStyle(
                                  height: 1.35,
                                  fontSize: 15)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3) 延伸閱讀
                  BubbleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Further reading',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        if (urls.isEmpty)
                          Text('No links',
                              style: TextStyle(color: tokens.textSecondary))
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
                                          const SnackBar(
                                              content: Text('Could not open link')),
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
            error: (e, _) => Center(child: Text('saved error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('detail error: $e')),
      ),
    );
  }

  Widget _chip(String text) => Builder(
        builder: (context) {
          final tokens = context.tokens;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
