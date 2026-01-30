import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final savedAsync = ref.watch(savedItemsProvider);
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        title: const Text('Detail'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: itemAsync.when(
        data: (item) {
          final urls = _parseUrls(item.sourceUrl);

          return savedAsync.when(
            data: (savedMap) {
              final SavedContent? saved = savedMap[item.id];

              // 檢查是否登入
              String? uid;
              try {
                uid = ref.read(uidProvider);
              } catch (_) {
                return const Center(child: Text('請先登入以使用此功能'));
              }

              final repo = ref.read(libraryRepoProvider);

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // 0) Header
                  BubbleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.anchorGroup,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(item.anchor,
                            style: TextStyle(color: tokens.textSecondary)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _chip('intent：${item.intent}'),
                            _chip('◆${item.difficulty}'),
                            _chip('L1'),
                            _chip('Day ${item.pushOrder}/365'),
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
                        const Text('今日一句',
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
                                    const SnackBar(content: Text('已複製')));
                              },
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('複製'),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('可在此串接分享功能')));
                              },
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('分享'),
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
                                  final productName = product?.title ?? '未知產品';
                                  
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
                              const SnackBar(content: Text('無法獲取產品資訊')),
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
                              const SnackBar(content: Text('已標記為完成')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('操作失敗: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('完成'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2) 深度解析（Excel deepAnalysis 欄位）
                  BubbleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('深度解析',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        if (item.deepAnalysis.isEmpty)
                          Text('目前沒有內容',
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
                        const Text('延伸閱讀',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        if (urls.isEmpty)
                          Text('目前沒有連結',
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
                                              content: Text('無法開啟此連結')),
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
