import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bubble_library/providers/providers.dart';
import '../../bubble_library/models/user_library.dart';
import '../bubble_library/models/product.dart';
import '../bubble_library/notifications/push_orchestrator.dart';
import '../bubble_library/notifications/scheduled_push_cache.dart';
import '../notifications/skip_next_store.dart';
import '../notifications/push_timeline_provider.dart';
import '../bubble_library/ui/product_library_page.dart';
import 'push_exclusion_store.dart';
import '../localization/app_language_provider.dart';
import '../localization/app_strings.dart';

import 'timeline_meta_mode.dart';
import 'widgets/timeline_widgets.dart';
import 'widgets/push_hint.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';

class PushTimelineList extends ConsumerWidget {
  final bool showTopBar; // Sheet 用 false, Page 用 true
  final VoidCallback? onClose;
  final int? limit; // 限制顯示數量（null = 全部）
  final bool dense; // 緊湊模式（用於預覽）

  const PushTimelineList({
    super.key,
    this.showTopBar = false,
    this.onClose,
    this.limit,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final lang = ref.watch(appLanguageProvider);
    String uid;
    try {
      uid = ref.read(uidProvider);
    } catch (_) {
      return Center(child: Text(uiString(lang, 'sign_in_to_use_feature')));
    }

    final metaMode = ref.watch(timelineMetaModeProvider);

    // ✅ 方案 A：改用本機排程快取（ScheduledPushCache）
    // 讓「未來 3 天時間表」與泡泡庫卡片、實際 OS 通知保持一致
    final timelineAsync = ref.watch(scheduledCacheProvider);
    final productsAsync = ref.watch(productsMapProvider);
    final libAsync = ref.watch(libraryProductsProvider);
    final savedAsync = ref.watch(savedItemsProvider);
    final globalPushAsync = ref.watch(globalPushSettingsProvider);

    Widget topBar() {
      if (!showTopBar) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, 0, AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              uiString(lang, 'push_timeline_header'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          IconButton(
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: uiString(lang, 'push_timeline_tooltip'),
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              // 透過單一入口重排，內部會自動刷新 scheduledCacheProvider
              await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(uiString(lang, 'rescheduled_next_3_days')),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
    }

    Widget sheetHeader() {
      if (showTopBar) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, 0, AppSpacing.xs),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 8,
              decoration: BoxDecoration(
                color: tokens.cardBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    uiString(lang, 'push_timeline_header'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: uiString(lang, 'tooltip_reschedule'),
                  icon: const Icon(Icons.refresh),
                  onPressed: () async {
                    // 透過單一入口重排，內部會自動刷新 scheduledCacheProvider
                    await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(uiString(lang, 'rescheduled_next_3_days')),
                        ),
                      );
                    }
                  },
                ),
                IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: uiString(lang, 'tooltip_close'),
                  icon: const Icon(Icons.close),
                  onPressed: onClose ?? () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return productsAsync.when(
      data: (productsMap) {
        return libAsync.when(
          data: (lib) {
            final libMap = <String, dynamic>{};
            for (final lp in lib) {
              libMap[lp.productId] = lp;
            }

            return savedAsync.when(
              data: (savedMap) {
                return globalPushAsync.when(
                  data: (globalPush) {
                    return timelineAsync.when(
                      data: (entries) {
                        if (entries.isEmpty) {
                          // 檢查為什麼沒有排程
                          final pushingProducts = lib.where((e) => !e.isHidden && e.pushEnabled).toList();
                          String emptyMessage;
                          if (!globalPush.enabled) {
                            emptyMessage = uiString(lang, 'timeline_empty_global_off');
                          } else if (pushingProducts.isEmpty) {
                            emptyMessage = uiString(lang, 'timeline_empty_no_products');
                          } else {
                            emptyMessage = uiString(lang, 'timeline_empty_no_scheduled');
                          }
                          
                          return Column(
                            children: [
                              if (showTopBar) topBar() else sheetHeader(),
                              Expanded(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          !globalPush.enabled 
                                            ? Icons.notifications_off
                                            : pushingProducts.isEmpty
                                              ? Icons.notifications_paused
                                              : Icons.schedule_outlined,
                                          size: 64,
                                          color: tokens.textSecondary,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          emptyMessage,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: tokens.textPrimary,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                    // build rows (header + items)
                    final rows = <TLRow>[];
                    final grouped = <String, List<ScheduledPushEntry>>{};
                    
                    // ✅ 去重：根據 notificationId 或 (contentItemId + when) 組合去重
                    final seen = <String>{};
                    final uniqueEntries = <ScheduledPushEntry>[];
                    for (final e in entries) {
                      // 優先使用 notificationId 去重（如果存在）
                      String key;
                      if (e.notificationId != null) {
                        key = 'nid:${e.notificationId}';
                      } else {
                        // 否則使用 contentItemId + when 組合
                        final contentItemId = e.payload['contentItemId']?.toString() ?? '';
                        key = 'cid:${contentItemId}_${e.when.millisecondsSinceEpoch}';
                      }
                      
                      if (!seen.contains(key)) {
                        seen.add(key);
                        uniqueEntries.add(e);
                      }
                    }
                    
                    // 如果有限制，先限制 entries
                    final itemsToProcess = limit != null && limit! > 0
                        ? uniqueEntries.take(limit!).toList()
                        : uniqueEntries;
                    
                    for (final e in itemsToProcess) {
                      final dk = tlDayKey(e.when);
                      grouped.putIfAbsent(dk, () => []).add(e);
                    }

                    final dayKeys = grouped.keys.toList()..sort();
                    for (final dk in dayKeys) {
                      rows.add(TLRow.header(dk));

                      final list = (grouped[dk] ?? <ScheduledPushEntry>[])..sort((a, b) {
                        return a.when.compareTo(b.when);
                      });

                      // 計算同日同商品的第 N 則（同一天、同一商品）
                      final perProdCounter = <String, int>{};
                      for (final e in list) {
                        final productId =
                            e.payload['productId']?.toString() ?? '';
                        if (productId.isEmpty) {
                          continue;
                        }
                        final n = (perProdCounter[productId] ?? 0) + 1;
                        perProdCounter[productId] = n;
                        rows.add(TLRow.item(e, seqInDayForProduct: n));
                      }
                    }

                    return Column(
                      children: [
                        if (showTopBar) topBar() else sheetHeader(),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
                            itemCount: rows.length,
                            itemBuilder: (context, i) {
                              final r = rows[i];
                              if (r.isHeader) {
                                if (dense) {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(0, AppSpacing.xs, 0, AppSpacing.xs),
                                    child: Text(
                                      r.dayKey ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: tokens.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                } else {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, AppSpacing.xs),
                                    child: Text(
                                      r.dayKey ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                  );
                                }
                              }

                              if (r.item == null) {
                                return const SizedBox.shrink();
                              }
                              final entry = r.item as ScheduledPushEntry;
                              final when = entry.when;
                              final payload = entry.payload;
                              final productId =
                                  payload['productId']?.toString() ?? '';
                              final contentItemId =
                                  payload['contentItemId']?.toString() ?? '';

                              // Day N：從 payload.pushOrder 取得（若有）
                              final day = (payload['pushOrder'] as num?)
                                      ?.toInt() ??
                                  0;

                              final productTitle = productsMap[productId]?.displayTitle(lang) ?? productId;
                              // 第一行、第二行都用 product title
                              final displayTitle = productTitle;

                              // 第二行：產品名稱（product title）
                              final displayPreview = productTitle.isNotEmpty
                                  ? productTitle
                                  : (day > 0 ? uiString(lang, 'day_label').replaceFirst('{n}', '$day') : productId);

                              final lp = libMap[productId] as UserLibraryProduct?;

                              String metaText() {
                                switch (metaMode) {
                                  case TimelineMetaMode.day:
                                    return ''; // Day 標籤已移除
                                  case TimelineMetaMode.push:
                                    return lp != null ? pushHintFor(lp, lang) : '';
                                  case TimelineMetaMode.nth:
                                    return '';
                                }
                              }

                              final saved = savedMap[contentItemId];

                              // 判斷「同一天內第一/最後」做線條收尾（簡單判斷：前後是不是 header）
                              final prevIsHeader = i == 0 ? true : rows[i - 1].isHeader;
                              final nextIsHeader =
                                  i == rows.length - 1 ? true : rows[i + 1].isHeader;

                              return tlTimelineRow(
                                context: context,
                                when: when,
                                title: displayTitle,
                                preview: displayPreview,
                                metaText: metaText(),
                                dayN: null, // 第一行不顯示 Day N，只顯示 product title
                                saved: saved,
                                seqInDay: null,
                                isFirst: prevIsHeader,
                                isLast: nextIsHeader,
                                doneLabel: uiString(lang, 'done'),
                                savedLabel: uiString(lang, 'saved_label'),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProductLibraryPage(
                                        productId: productId,
                                        isWishlistPreview: false,
                                        initialContentItemId: contentItemId,
                                      ),
                                    ),
                                  );
                                },
                                trailing: dense
                                    ? null // 緊湊模式不顯示 trailing
                                    : Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.visibility, size: 16),
                                            label: Text(uiString(lang, 'view')),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: AppSpacing.sm,
                                                vertical: AppSpacing.xs,
                                              ),
                                            ),
                                            onPressed: () async {
                                              // 標記推播為已開啟
                                              await PushExclusionStore.markOpened(uid, contentItemId);

                                              // ignore: use_build_context_synchronously
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => ProductLibraryPage(
                                                    productId: productId,
                                                    isWishlistPreview: false,
                                                    initialContentItemId: contentItemId,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.skip_next, size: 16),
                                            label: Text(uiString(lang, 'skip')),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: AppSpacing.sm,
                                                vertical: AppSpacing.xs,
                                              ),
                                            ),
                                            onPressed: () async {
                                              await SkipNextStore.add(uid, contentItemId);
                                              // 透過單一入口重排，內部會自動刷新 scheduledCacheProvider
                                              await PushOrchestrator.rescheduleNextDays(
                                                  ref: ref, days: 3);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      uiString(lang, 'skipped_and_rescheduled'),
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                              );
                            },
                          ),
                        ),
                      ],
                  );
                },
                loading: () => Column(
                  children: [
                    if (showTopBar) topBar() else sheetHeader(),
                    const Expanded(child: Center(child: CircularProgressIndicator())),
                  ],
                ),
                error: (e, _) =>
                    Center(child: Text('${uiString(lang, 'timeline_error')}$e')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('${uiString(lang, 'global_push_error')}$e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('${uiString(lang, 'saved_error')}$e')),
      );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('${uiString(lang, 'library_error')}$e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          uiString(lang, 'timeline_load_error'),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
