import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../models/product.dart';
import '../models/content_item.dart';
import '../models/user_library.dart';
import '../../localization/app_language.dart';
import '../../localization/app_language_provider.dart';
import '../../localization/app_strings.dart';
import 'detail_page.dart';
import 'widgets/bubble_card.dart';
import '../../../theme/app_tokens.dart';
import '../notifications/scheduled_push_cache.dart';

class ProductLibraryPage extends ConsumerStatefulWidget {
  final String productId;
  final bool isWishlistPreview;

  // ✅ 新增：指定要跳到哪一張 content
  final String? initialContentItemId;

  const ProductLibraryPage({
    super.key,
    required this.productId,
    required this.isWishlistPreview,
    this.initialContentItemId,
  });

  @override
  ConsumerState<ProductLibraryPage> createState() => _ProductLibraryPageState();
}

class _ProductLibraryPageState extends ConsumerState<ProductLibraryPage> with WidgetsBindingObserver {
  final Map<String, GlobalKey> _itemKeys = {};
  bool _didJump = false;
  int _jumpAttempts = 0;

  void _tryJumpToTarget() {
    final targetId = widget.initialContentItemId;
    if (targetId == null || targetId.isEmpty) return;
    if (_didJump) return;
    if (_jumpAttempts >= 8) return; // 避免無限嘗試

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[targetId];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.15, // 讓目標卡片偏上，視覺更舒服
        );
        _didJump = true;
        return;
      }
      _jumpAttempts += 1;
      // 下一次 build 再試
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    // 監聽頁面生命週期，當頁面重新可見時刷新數據
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 當 app 從背景回到前景時，刷新 savedItemsProvider
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(savedItemsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final productsAsync = ref.watch(productsMapProvider);
    final contentsAsync = ref.watch(contentByProductProvider(widget.productId));
    final savedAsync = ref.watch(savedItemsProvider);
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        title: Text(uiString(lang, 'content_title')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: productsAsync.when(
        data: (productsMap) {
          final product = productsMap[widget.productId];
          if (product == null) {
            return Center(child: Text(uiString(lang, 'product_not_found')));
          }

          return contentsAsync.when(
            data: (items) {
              final showItems = widget.isWishlistPreview
                  ? items.take(product.trialLimit).toList()
                  : items;

              return savedAsync.when(
                data: (savedMap) {
                  // ✅ 嘗試跳轉到目標 content
                  _tryJumpToTarget();

                  final completed = showItems
                      .where((it) => savedMap[it.id]?.learned ?? false)
                      .length;
                  final total = showItems.length;
                  final progress =
                      total > 0 ? completed / total : 0.0;
                  final percent = (progress * 100).round();

                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      BubbleCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bubble_chart_outlined,
                                    size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(product.displayTitle(lang),
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          _chip(
                                            widget.isWishlistPreview
                                                ? uiString(lang, 'preview')
                                                : uiString(lang, 'my_library'),
                                          ),
                                          _chip(
                                            '${showItems.length} ${uiString(lang, 'items')}',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(tokens.cardRadius),
                                gradient: tokens.cardGradient,
                                color: tokens.cardGradient == null
                                    ? tokens.cardBg
                                    : null,
                                border: Border.all(
                                    color: tokens.cardBorder, width: 1),
                                boxShadow: tokens.cardShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(uiString(lang, 'your_progress'),
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: tokens.textPrimary)),
                                      Text('$percent%',
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: tokens.textPrimary)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 8,
                                      backgroundColor: tokens.cardBorder
                                          .withValues(alpha: 0.3),
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              tokens.primary),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                      uiString(lang, 'completed_cards')
                                          .replaceFirst('{done}', '$completed')
                                          .replaceFirst('{total}', '$total'),
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: tokens.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...showItems.map((it) {
                        final saved = savedMap[it.id];

                        // ✅ 每張卡都給一個 GlobalKey，讓 ensureVisible 找得到
                        final k = _itemKeys.putIfAbsent(it.id, () => GlobalKey());

                        final isTarget = (it.id == widget.initialContentItemId);

                        // ✅ 檢查是否應該顯示紅框（基於完成狀態和下一則推播）
                        // 只有未完成的內容才需要檢查
                        final shouldShowRedBorder = (saved?.learned ?? false) == false
                            ? ref.watch(_shouldShowRedBorderProvider('${widget.productId}|${it.pushOrder}'))
                            : null;

                        // 原本的卡片 widget
                        final original = Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: BubbleCard(
                            onTap: () async {
                              // ✅ 導航到 detail 頁面，並在返回時刷新數據
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        DetailPage(contentItemId: it.id)),
                              );
                              // ✅ 從 detail 頁返回時，強制刷新 savedItemsProvider
                              // 確保卡片顯示最新的狀態（learned/reviewLater/favorite）
                              ref.invalidate(savedItemsProvider);
                            },
                            child: _contentCard(context, ref, it, saved, lang),
                          ),
                        );

                        // 可選：目標卡片加一個淡淡外框，讓使用者知道「跳到這張」
                        // ✅ 未完成且 pushOrder < 下一則推播的卡片加紅框
                        return Container(
                          key: k, // ✅ GlobalKey 要掛在真正的 Element 上，ensureVisible 才抓得到 context
                          child: shouldShowRedBorder != null
                              ? shouldShowRedBorder.when(
                                  data: (showRed) {
                                    final tokens = context.tokens;
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(tokens.cardRadius),
                                        border: showRed
                                            ? Border.all(
                                                width: 2,
                                                color: Colors.red,
                                              )
                                            : isTarget
                                                ? Border.all(
                                                    width: 1.5,
                                                    color: Colors.blue.withValues(alpha: 0.5),
                                                  )
                                                : null,
                                      ),
                                      child: original,
                                    );
                                  },
                                  loading: () => AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: isTarget
                                          ? Border.all(
                                              width: 1.5,
                                              color: Colors.blue.withValues(alpha: 0.5),
                                            )
                                          : null,
                                    ),
                                    child: original,
                                  ),
                                  error: (_, __) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: isTarget
                                          ? Border.all(
                                              width: 1.5,
                                              color: Colors.blue.withValues(alpha: 0.5),
                                            )
                                          : null,
                                    ),
                                    child: original,
                                  ),
                                )
                              : AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: isTarget
                                        ? Border.all(
                                            width: 1.5,
                                            color: Colors.blue.withValues(alpha: 0.5),
                                          )
                                        : null,
                                  ),
                                  child: original,
                                ),
                        );
                      }),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('${uiString(lang, 'saved_error')}$e')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('${uiString(lang, 'content_error')}$e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            uiString(lang, 'product_content_load_error'),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _contentCard(BuildContext context, WidgetRef ref, ContentItem it, SavedContent? saved, AppLanguage lang) {
    try {
      ref.read(uidProvider);
    } catch (_) {
      return Center(child: Text(uiString(lang, 'sign_in_first')));
    }

    String ellipsize(String s, int max) =>
        s.length <= max ? s : '${s.substring(0, max)}…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 標題和序號（橘框改為 anchor）
        Row(
          children: [
            Expanded(
              child: Text(
                it.displayAnchor(lang).isNotEmpty ? it.displayAnchor(lang) : it.displayAnchorGroup(lang),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
            Builder(
              builder: (context) {
                final tokens = context.tokens;
                return Text(
                  '#${it.seq}',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 內容預覽（增加字數限制，最多2行）
        Text(
          ellipsize(it.displayContent(lang), 100),
          style: const TextStyle(fontSize: 15, height: 1.4),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        // 操作按鈕：只顯示狀態，不可點擊
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: Icon((saved?.learned ?? false)
                  ? Icons.check_circle
                  : Icons.check_circle_outline),
              onPressed: null,
              tooltip: (saved?.learned ?? false)
                  ? uiString(lang, 'done')
                  : uiString(lang, 'pending'),
            ),
            IconButton(
              icon: Icon(
                  (saved?.favorite ?? false) ? Icons.star : Icons.star_border),
              onPressed: null,
              tooltip: (saved?.favorite ?? false) ? uiString(lang, 'saved_label') : uiString(lang, 'not_saved'),
            ),
          ],
        ),
      ],
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

/// Provider：檢查是否應該顯示紅框（基於完成狀態和下一則推播）
/// 參數格式：'$productId|$pushOrder'
/// 邏輯：如果當前內容未完成且 pushOrder < 下一則推播的 pushOrder，則顯示紅框
final _shouldShowRedBorderProvider = FutureProvider.family<bool, String>((ref, key) async {
  final parts = key.split('|');
  if (parts.length != 2) return false;
  final productId = parts[0];
  final currentPushOrder = int.tryParse(parts[1]) ?? 0;
  
  // ✅ 1. 獲取下一則推播（同一 product 的）
  final cache = ScheduledPushCache();
  final upcoming = await cache.loadSortedUpcoming();
  
  // 找到同一 productId 的下一則推播（按時間排序，最早的那個）
  ScheduledPushEntry? nextPush;
  for (final entry in upcoming) {
    final payloadProductId = entry.payload['productId']?.toString();
    if (payloadProductId == productId) {
      nextPush = entry;
      break; // 找到第一個就是最早的
    }
  }
  
  // 如果沒有下一則推播，不顯示紅框
  if (nextPush == null) return false;
  
  // ✅ 2. 獲取下一則推播的 pushOrder
  final nextPushOrderRaw = nextPush.payload['pushOrder'];
  final nextPushOrder = nextPushOrderRaw is int
      ? nextPushOrderRaw
      : (nextPushOrderRaw is num ? nextPushOrderRaw.toInt() : 0);
  
  // ✅ 3. 如果當前 pushOrder < 下一則推播的 pushOrder，且未完成，顯示紅框
  // 注意：這裡假設當前內容未完成（在調用時已經檢查過 saved?.learned == false）
  return currentPushOrder < nextPushOrder;
});
