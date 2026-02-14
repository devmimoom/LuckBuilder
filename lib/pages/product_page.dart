import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/v2_providers.dart';
import '../bubble_library/providers/providers.dart';
import '../ui/glass.dart';
import '../theme/app_tokens.dart';
import '../theme/layout_constants.dart';
import '../widgets/rich_sections/user_learning_store.dart';
import '../notifications/coming_soon_remind_store.dart';
import '../bubble_library/notifications/notification_service.dart';
import '../bubble_library/ui/product_library_page.dart';
import '../collections/wishlist_provider.dart';
import '../iap/credits_pack_store_sheet.dart';
import '../providers/analytics_provider.dart';
import '../widgets/app_card.dart';

class ProductPage extends ConsumerStatefulWidget {
  final String productId;
  const ProductPage({super.key, required this.productId});

  @override
  ConsumerState<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends ConsumerState<ProductPage> {
  bool _didLogAnalytics = false;

  @override
  void initState() {
    super.initState();
    // 保底記錄：進入產品頁就記一次學習
    unawaited(UserLearningStore().markGlobalLearnedToday());
  }

  @override
  Widget build(BuildContext context) {
    final prod = ref.watch(productProvider(widget.productId));
    if (prod.hasValue && prod.value != null && !_didLogAnalytics) {
      _didLogAnalytics = true;
      final p = prod.value!;
      unawaited(ref.read(analyticsProvider).logScreenView(screenName: 'product'));
      unawaited(ref.read(analyticsProvider).logEvent('view_item', {
        'item_id': widget.productId,
        'item_name': p.title,
      }));
    }
    final previews = ref.watch(previewItemsProvider(widget.productId));
    final comingSoonSet = ref.watch(comingSoonIdsProvider);
    final tokens = context.tokens;

    final localWishAsync = ref.watch(localWishlistProvider);

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        title: const Text('Product'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          localWishAsync.when(
            data: (wish) {
              final isWish = wish.any((e) => e.productId == widget.productId);
              return IconButton(
                tooltip: isWish ? 'Remove from favorites' : 'Add to favorites',
                icon: Icon(isWish ? Icons.bookmark : Icons.bookmark_outline),
                onPressed: () async {
                  await ref.read(localWishlistNotifierProvider).toggleCollect(widget.productId);
                  // ✅ 添加操作反馈
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isWish ? 'Removed from favorites.' : 'Added to favorites.'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: prod.when(
        data: (p) {
          if (p == null) return const Center(child: Text('Product not found or not yet available.'));
          final isFullAccessUser = ref.watch(isFullAccessUserProvider);
          final now = DateTime.now();
          final releaseAt = p.releaseAt;
          final isComingSoon = comingSoonSet.contains(widget.productId) ||
              (releaseAt != null && releaseAt.isAfter(now));
          final specs = [p.spec1Label, p.spec2Label, p.spec3Label, p.spec4Label]
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 封面 + 標題 — 同一張卡片（與首頁 ProductRail 一致）
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 封面圖片（1200x800 = 3:2）
                    if (p.coverImageUrl != null && p.coverImageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(tokens.cardRadius),
                          topRight: Radius.circular(tokens.cardRadius),
                        ),
                        child: AspectRatio(
                          aspectRatio: kCoverAspectRatio,
                          child: CachedNetworkImage(
                            imageUrl: p.coverImageUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            placeholder: (context, url) => Container(
                              color: tokens.chipBg,
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            errorWidget: (context, url, error) =>
                                Container(
                              color: tokens.chipBg,
                              child: Icon(Icons.image_not_supported,
                                  size: 48, color: tokens.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    // 標題區塊
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title,
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: tokens.textPrimary)),
                          const SizedBox(height: 6),
                          Text('${p.topicId} · ${p.level}',
                              style: TextStyle(color: tokens.textSecondary)),
                          if (isComingSoon) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: tokens.cardBorder.withValues(alpha: 0.3),
                                border: Border.all(
                                    color: tokens.cardBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.lock_clock, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Coming soon',
                                    style: TextStyle(
                                      color: tokens.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          if ((p.levelGoal ?? '').isNotEmpty)
                            Text(p.levelGoal!,
                                style: TextStyle(color: tokens.textPrimary)),
                          const SizedBox(height: 6),
                          if ((p.levelBenefit ?? '').isNotEmpty)
                            Text(p.levelBenefit!,
                                style: TextStyle(color: tokens.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: specs
                    .map((s) => GlassCard(
                          radius: 999,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Text(s),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              Text('│ Preview',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary)),
              const SizedBox(height: 10),
              previews.when(
                data: (items) => SizedBox(
                  height: 230,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = (constraints.maxWidth * 0.78)
                          .clamp(260.0, kMaxPreviewCardWidth);
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final it = items[i];
                          return SizedBox(
                            width: cardWidth,
                            child: GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(it.anchor,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: tokens.textPrimary)),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: Text(it.content,
                                        maxLines: 5,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: tokens.textSecondary)),
                                  ),
                                  const SizedBox(height: 6),
                                  GlassCard(
                                    radius: 999,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    child: Text(
                                        '${it.intent} · d${it.difficulty}'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                loading: () => const SizedBox(
                    height: 230,
                    child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox(height: 230),
              ),
              if ((p.contentArchitecture ?? '').isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('│ Content structure',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary)),
                const SizedBox(height: 10),
                GlassCard(
                  radius: 26,
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      p.contentArchitecture!,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
                child: isComingSoon
                    ? const _ComingSoonBar()
                    : (p.creditsRequired == 0 || isFullAccessUser)
                        ? _FreeProductBar(
                            productId: widget.productId,
                            onAdded: _onFreeAdded(ref),
                            onStartLearning: _onStartLearning(),
                          )
                        : _CreditsProductBar(
                            productId: widget.productId,
                            creditsRequired: p.creditsRequired,
                            onRedeemed: _onUnlocked(ref),
                            onBuyCredits: () =>
                                showCreditsPackStoreSheet(context, ref),
                          ),
              ),
              if (isComingSoon) ...[
                const SizedBox(height: 12),
                localWishAsync.when(
                  data: (wish) {
                    String? uid;
                    try {
                      uid = ref.read(uidProvider);
                    } catch (_) {
                      uid = null;
                    }

                    final isWish = wish.any((w) => w.productId == widget.productId);

                    return Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(isWish ? Icons.favorite : Icons.favorite_border),
                            label: Text(isWish ? 'In wishlist' : 'Add to wishlist'),
                            onPressed: (uid == null)
                                ? null
                                : () async {
                                    if (isWish) {
                                      await ref.read(localWishlistNotifierProvider).remove(widget.productId);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Removed from wishlist.')),
                                        );
                                      }
                                    } else {
                                      await ref.read(localWishlistNotifierProvider).toggleCollect(widget.productId);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Added to wishlist.')),
                                        );
                                      }
                                    }
                                  },
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(
                    height: 44,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('wishlist error: $e'),
                ),
                const SizedBox(height: 10),

                // ✅ 上架提醒
                FutureBuilder<Map<String, int>>(
                  future: (() async {
                    String? uid;
                    try {
                      uid = ref.read(uidProvider);
                    } catch (_) {
                      uid = null;
                    }
                    if (uid == null) return <String, int>{};
                    return ComingSoonRemindStore.load(uid);
                  })(),
                  builder: (context, snap) {
                    String? uid;
                    try {
                      uid = ref.read(uidProvider);
                    } catch (_) {
                      uid = null;
                    }

                    final map = snap.data ?? <String, int>{};
                    final hasRemind = uid != null && map.containsKey(widget.productId);

                    final notifId = widget.productId.hashCode & 0x7fffffff;

                    return OutlinedButton.icon(
                      icon: Icon(hasRemind
                          ? Icons.notifications_active
                          : Icons.notifications_active_outlined),
                      label: Text(hasRemind ? 'Reminder set (tap to cancel)' : 'Notify me when available'),
                      onPressed: (uid == null)
                          ? null
                          : () async {
                              final ns = NotificationService();

                              if (hasRemind) {
                                await ComingSoonRemindStore.remove(
                                    uid: uid!, productId: widget.productId);
                                await ns.cancel(notifId);

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Reminder cancelled.')),
                                  );
                                }
                                // 讓 FutureBuilder 重新讀
                                if (context.mounted) {
                                  (context as Element).markNeedsBuild();
                                }
                                return;
                              }

                              // ✅ 有上架時間就用上架當天 09:00；沒有就退回明天 09:00（示意）
                              final now = DateTime.now();
                              final releaseAt = p.releaseAt;
                              final remindAt = (releaseAt != null)
                                  ? DateTime(releaseAt.year, releaseAt.month, releaseAt.day, 9)
                                  : DateTime(now.year, now.month, now.day, 9)
                                      .add(const Duration(days: 1));

                              await ComingSoonRemindStore.set(
                                uid: uid!,
                                productId: widget.productId,
                                remindAtMs: remindAt.millisecondsSinceEpoch,
                              );

                              await ns.schedule(
                                id: notifId,
                                when: remindAt,
                                title: 'OnePop available',
                                body: '${p.title} is now available. Come take a look!',
                                payload: {
                                  'type': 'coming_soon_remind',
                                  'productId': widget.productId,
                                },
                              );

                              if (context.mounted) {
                                final dateText = (releaseAt != null)
                                    ? '${remindAt.year}-${remindAt.month.toString().padLeft(2, '0')}-${remindAt.day.toString().padLeft(2, '0')} ${remindAt.hour.toString().padLeft(2, '0')}:${remindAt.minute.toString().padLeft(2, '0')}'
                                    : 'Tomorrow ${remindAt.hour.toString().padLeft(2, '0')}:${remindAt.minute.toString().padLeft(2, '0')}';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Reminder set: $dateText'),
                                  ),
                                );
                              }

                              // 讓 FutureBuilder 重新讀
                              if (context.mounted) {
                                (context as Element).markNeedsBuild();
                              }
                            },
                    );
                  },
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Load failed:',
                      style: TextStyle(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '$err',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> Function() _onUnlocked(WidgetRef ref) => () async {
        String? uid;
        try {
          uid = ref.read(uidProvider);
        } catch (_) {
          uid = null;
        }
        if (uid != null) {
          await ref.read(libraryRepoProvider).ensureLibraryProductExists(
                uid: uid,
                productId: widget.productId,
              );
          final wishlist = await ref.read(wishlistProvider.future);
          if (wishlist.any((w) => w.productId == widget.productId)) {
            await ref.read(localWishlistNotifierProvider).remove(widget.productId);
          }
          ref.invalidate(libraryProductsProvider);
          ref.invalidate(wishlistProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unlocked. You can enable banner notifications.')),
            );
          }
        }
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductLibraryPage(
                productId: widget.productId,
                isWishlistPreview: false,
              ),
            ),
          );
        }
      };

  Future<void> Function() _onFreeAdded(WidgetRef ref) => () async {
        String? uid;
        try {
          uid = ref.read(uidProvider);
        } catch (_) {
          uid = null;
        }
        if (uid == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sign in to add to your library.')),
            );
          }
          return;
        }
        await ref.read(libraryRepoProvider).ensureLibraryProductExists(
              uid: uid,
              productId: widget.productId,
            );
        final wishlist = await ref.read(wishlistProvider.future);
        if (wishlist.any((w) => w.productId == widget.productId)) {
          await ref.read(localWishlistNotifierProvider).remove(widget.productId);
        }
        ref.invalidate(libraryProductsProvider);
        ref.invalidate(wishlistProvider);
        ref.invalidate(creditsBalanceProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Added to your library.')),
          );
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductLibraryPage(
                productId: widget.productId,
                isWishlistPreview: false,
              ),
            ),
          );
        }
      };

  VoidCallback _onStartLearning() => () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductLibraryPage(
              productId: widget.productId,
              isWishlistPreview: false,
            ),
          ),
        );
      };
}

/// Coming soon：無購買按鈕，僅顯示即將上架
class _ComingSoonBar extends StatelessWidget {
  const _ComingSoonBar();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return GlassCard(
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, size: 20, color: tokens.primary),
                const SizedBox(width: 8),
                Text(
                  'Coming soon',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'This product is not yet available. Add to wishlist or set a reminder below.',
              style: TextStyle(
                fontSize: 13,
                height: 1.25,
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 免費產品：加入 Library 或開始學習（creditsRequired == 0）
class _FreeProductBar extends ConsumerWidget {
  final String productId;
  final Future<void> Function() onAdded;
  final VoidCallback onStartLearning;

  const _FreeProductBar({
    required this.productId,
    required this.onAdded,
    required this.onStartLearning,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libAsync = ref.watch(libraryProductsProvider);
    final inLibrary = libAsync.valueOrNull?.any((lp) =>
            lp.productId == productId && !lp.isHidden) ??
        false;
    final tokens = context.tokens;

    return GlassCard(
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    inLibrary ? 'In your library' : 'Free',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    inLibrary
                        ? 'Open and start.'
                        : 'Add to your library and start.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () async {
                if (inLibrary) {
                  onStartLearning();
                } else {
                  await onAdded();
                }
              },
              child: Text(inLibrary ? 'Start' : 'Add to Library'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 額度產品：用 N 額度兌換或購買額度（creditsRequired >= 1）
class _CreditsProductBar extends ConsumerWidget {
  final String productId;
  final int creditsRequired;
  final Future<void> Function() onRedeemed;
  final VoidCallback onBuyCredits;

  const _CreditsProductBar({
    required this.productId,
    required this.creditsRequired,
    required this.onRedeemed,
    required this.onBuyCredits,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(creditsBalanceProvider);
    final libAsync = ref.watch(libraryProductsProvider);
    final balance = balanceAsync.valueOrNull ?? 0;
    final inLibrary = libAsync.valueOrNull?.any((lp) =>
            lp.productId == productId && !lp.isHidden) ??
        false;
    final tokens = context.tokens;
    final canRedeem = !inLibrary && balance >= creditsRequired;

    return GlassCard(
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    inLibrary
                        ? 'In your library'
                        : canRedeem
                            ? 'Use $creditsRequired credit${creditsRequired > 1 ? 's' : ''}'
                            : '$creditsRequired credit${creditsRequired > 1 ? 's' : ''} to unlock',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    inLibrary
                        ? 'Open and start.'
                        : balanceAsync.hasValue
                            ? 'Balance: $balance. ${canRedeem ? 'Unlock this product.' : 'This product costs $creditsRequired credit${creditsRequired > 1 ? 's' : ''}. Get more to unlock.'}'
                            : 'Loading…',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            inLibrary
                ? FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductLibraryPage(
                          productId: productId,
                          isWishlistPreview: false,
                        ),
                      ),
                    ),
                    child: const Text('Start'),
                  )
                : canRedeem
                    ? FilledButton(
                        onPressed: () async {
                          String? uid;
                          try {
                            uid = ref.read(uidProvider);
                          } catch (_) {
                            uid = null;
                          }
                          if (uid == null) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Sign in to use credits.')),
                              );
                            }
                            return;
                          }
                          try {
                            await ref.read(creditsRepoProvider).redeemCredits(
                                  uid: uid,
                                  productId: productId,
                                  amount: creditsRequired,
                                );
                            ref.invalidate(creditsBalanceProvider);
                            ref.invalidate(libraryProductsProvider);
                            ref.invalidate(wishlistProvider);
                            await onRedeemed();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed: $e')),
                              );
                            }
                          }
                        },
                        child: Text(
                            'Use $creditsRequired credit${creditsRequired > 1 ? 's' : ''}'),
                      )
                    : FilledButton(
                        onPressed: onBuyCredits,
                        child: const Text('Buy credits'),
                      ),
          ],
        ),
      ),
    );
  }
}
