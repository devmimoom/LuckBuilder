import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/app_card.dart';

// 讀泡泡庫資料（已購買/推播設定/進度）
import '../../bubble_library/providers/providers.dart';

// 讀排程快取（Timeline 真資料同來源）
import '../../bubble_library/notifications/scheduled_push_cache.dart';

class HomeContinueSection extends ConsumerWidget {
  final void Function(String productId, int day) onContinue;
  const HomeContinueSection({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 未登入：直接顯示提示（避免 uidProvider throw）
    try {
      ref.read(uidProvider);
    } catch (_) {
      return AppCard(
        child: Text(
          'Sign in to see Continue: recent topics, day progress, and next notification.',
          style: TextStyle(color: context.tokens.textSecondary),
        ),
      );
    }

    final tokens = context.tokens;
    final libAsync = ref.watch(libraryProductsProvider);
    final productsAsync = ref.watch(productsMapProvider);

    // 讀未來 3 天排程（真資料）
    final scheduleAsync = ref.watch(_scheduledUpcomingProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Continue',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: tokens.textPrimary)),
          const SizedBox(height: 10),
          productsAsync.when(
            data: (productsMap) {
              return libAsync.when(
                data: (lib) {
                  // 只顯示可見且存在的商品
                  final visible = lib
                      .where((e) =>
                          !e.isHidden && productsMap.containsKey(e.productId))
                      .toList();

                  if (visible.isEmpty) {
                    return Text('No purchased topics yet. Browse categories or search.',
                        style: TextStyle(color: tokens.textSecondary));
                  }

                  // 排序：lastOpenedAt（若存在）優先，否則用 purchasedAt
                  visible.sort((a, b) {
                    final ta = _safeLastOpenedAt(a) ?? a.purchasedAt;
                    final tb = _safeLastOpenedAt(b) ?? b.purchasedAt;
                    return tb.compareTo(ta);
                  });

                  final top = visible.take(3).toList();

                  // 取排程清單（若還在 loading 就給空 list）
                  final upcoming = scheduleAsync.asData?.value ??
                      const <ScheduledPushEntry>[];

                  return Column(
                    children: [
                      for (final lp in top) ...[
                        _ContinueCard(
                          title: productsMap[lp.productId]!.title,
                          productId: lp.productId,
                          day: lp.progress.nextSeq,
                          pushEnabled: lp.pushEnabled,
                          nextEntry: _nextEntryFor(upcoming, lp.productId),
                          onTap: () =>
                              onContinue(lp.productId, lp.progress.nextSeq),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(
                  'We couldn’t load your library right now. Please try again later.',
                  style: TextStyle(color: tokens.textSecondary),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              'We couldn’t load your recent topics right now. Please try again later.',
              style: TextStyle(color: tokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// 讀未來 3 天排程（真資料）
final _scheduledUpcomingProvider =
    FutureProvider<List<ScheduledPushEntry>>((ref) async {
  return ScheduledPushCache()
      .loadSortedUpcoming(horizon: const Duration(days: 3));
});

ScheduledPushEntry? _nextEntryFor(
    List<ScheduledPushEntry> list, String productId) {
  final now = DateTime.now();
  final filtered = list
      .where((e) =>
          e.when.isAfter(now) &&
          e.payload['productId']?.toString() == productId)
      .toList();
  if (filtered.isEmpty) return null;
  filtered.sort((a, b) => a.when.compareTo(b.when));
  return filtered.first;
}

DateTime? _safeLastOpenedAt(Object lp) {
  // 兼容不同 model 版本：若沒有 lastOpenedAt 不會編譯炸掉
  try {
    final dyn = lp as dynamic;
    final v = dyn.lastOpenedAt;
    if (v is DateTime) return v;
  } catch (_) {}
  return null;
}

class _ContinueCard extends StatelessWidget {
  final String title;
  final String productId;
  final int day;
  final bool pushEnabled;
  final ScheduledPushEntry? nextEntry;
  final VoidCallback onTap;

  const _ContinueCard({
    required this.title,
    required this.productId,
    required this.day,
    required this.pushEnabled,
    required this.nextEntry,
    required this.onTap,
  });

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _dayFromPayload(ScheduledPushEntry e) {
    final pushOrder = e.payload['pushOrder'];
    if (pushOrder is int) return '（$pushOrder）';
    if (pushOrder is num) return '（${pushOrder.toInt()}）';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final nextLine = !pushEnabled
        ? 'Notifications off'
        : (nextEntry == null
            ? 'No schedule for next 3 days'
            : 'Next: ${_fmtTime(nextEntry!.when)} · ${nextEntry!.title}${_dayFromPayload(nextEntry!)}');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          border: Border.all(color: tokens.cardBorder.withValues(alpha: 0.5)),
          color: tokens.cardBg.withValues(alpha: 0.3),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: tokens.textPrimary)),
                  const SizedBox(height: 6),
                  Text('$day/365 · $productId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: tokens.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(nextLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: tokens.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: tokens.buttonGradient,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('Continue',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
