import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_tokens.dart';
import '../../../theme/layout_constants.dart';
import '../../app_card.dart';

import '../../../providers/v2_providers.dart';
import '../../../bubble_library/providers/providers.dart';
import '../../../collections/wishlist_provider.dart';
import '../../../data/models.dart';
import '../../../pages/product_page.dart';

class CategoryNetflixRails extends ConsumerWidget {
  const CategoryNetflixRails({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newArrivalsAsync = ref.watch(newArrivalsProvider);
    final hotAsync = ref.watch(featuredProductsProvider('hot_all'));
    final weeklyAsync = ref.watch(featuredProductsProvider('weekly_pick'));

    final libAsync = _safeLib(ref);
    final wishAsync = _safeWish(ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(context, 'Explore'),
        const SizedBox(height: 10),

        // 適合你（只有登入才可能有資料）
        hotAsync.when(
          data: (hotList) {
            return libAsync.when(
              data: (lib) {
                return wishAsync.when(
                  data: (wish) {
                    // 適合你：推播中/最愛/最近開啟/願望清單（從 hot list 篩選）
                    final hotMap = <String, Product>{
                      for (final p in hotList) p.id: p
                    };
                    final forYou =
                        _buildForYou(hotMap, lib, wish).take(10).toList();

                    if (forYou.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _railTitle(context, 'For you'),
                        _rail(context, forYou),
                        const SizedBox(height: 18),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // 新上架
        newArrivalsAsync.when(
          data: (newList) => newList.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _railTitle(context, 'New'),
                    _rail(context, newList.take(10).toList()),
                    const SizedBox(height: 18),
                  ],
                ),
          loading: () {
            final sw = MediaQuery.of(context).size.width;
            final cw = (sw * 0.7).clamp(200.0, kMaxCardWidth);
            return SizedBox(
              height: cw / kCoverAspectRatio + 80,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          error: (_, __) => const SizedBox.shrink(),
        ),

        // 熱門
        hotAsync.when(
          data: (hot) => hot.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _railTitle(context, 'Popular'),
                    _rail(context, hot.take(10).toList()),
                    const SizedBox(height: 18),
                  ],
                ),
          loading: () {
            final sw = MediaQuery.of(context).size.width;
            final cw = (sw * 0.7).clamp(200.0, kMaxCardWidth);
            return SizedBox(
              height: cw / kCoverAspectRatio + 80,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          error: (_, __) => const SizedBox.shrink(),
        ),

        // 精選
        weeklyAsync.when(
          data: (wk) => wk.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _railTitle(context, 'Picks'),
                    _rail(context, wk.take(10).toList()),
                  ],
                ),
          loading: () {
            final sw = MediaQuery.of(context).size.width;
            final cw = (sw * 0.7).clamp(200.0, kMaxCardWidth);
            return SizedBox(
              height: cw / kCoverAspectRatio + 80,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _title(BuildContext context, String t) => Text(
        '│ $t',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: context.tokens.textPrimary,
        ),
      );

  Widget _railTitle(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: context.tokens.textPrimary)),
      );

  Widget _rail(BuildContext context, List<Product> products) {
    final tokens = context.tokens;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth * 0.7).clamp(200.0, kMaxCardWidth);
    final imageHeight = cardWidth / kCoverAspectRatio;
    const textArea = 80.0; // 原 190-110
    final railHeight = imageHeight + textArea;

    return SizedBox(
      height: railHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(
          width: cardWidth,
          child: AppCard(
            padding: EdgeInsets.zero,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProductPage(productId: products[i].id),
            )),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (products[i].coverImageUrl != null &&
                    products[i].coverImageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    child: CachedNetworkImage(
                      imageUrl: products[i].coverImageUrl!,
                      height: imageHeight,
                      width: double.infinity,
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
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(products[i].title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: tokens.textPrimary)),
                        const SizedBox(height: 6),
                        Text('${products[i].topicId} · ${products[i].level}',
                            style: TextStyle(
                                color: tokens.textSecondary, fontSize: 12)),
                        const Spacer(),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text('View ›',
                              style: TextStyle(
                                  color: tokens.primary,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AsyncValue<List<dynamic>> _safeLib(WidgetRef ref) {
    try {
      ref.read(uidProvider);
      return ref.watch(libraryProductsProvider);
    } catch (_) {
      return const AsyncValue.data(<dynamic>[]);
    }
  }

  AsyncValue<List<dynamic>> _safeWish(WidgetRef ref) {
    try {
      ref.read(uidProvider);
      return ref.watch(localWishlistProvider);
    } catch (_) {
      return const AsyncValue.data(<dynamic>[]);
    }
  }

  List<Product> _buildForYou(
    Map<String, Product> hotMap,
    List<dynamic> lib,
    List<dynamic> wish,
  ) {
    final result = <Product>[];
    final used = <String>{};

    void add(String pid) {
      if (used.contains(pid)) return;
      final p = hotMap[pid];
      if (p == null) return; // 只顯示 hot list 裡有的
      used.add(pid);
      result.add(p);
    }

    // 推播中
    for (final lp in lib) {
      try {
        if ((lp as dynamic).isHidden == true) continue;
        if ((lp as dynamic).pushEnabled == true) {
          add((lp as dynamic).productId.toString());
        }
      } catch (_) {}
    }
    // 最愛（已購買+願望）
    for (final lp in lib) {
      try {
        if ((lp as dynamic).isHidden == true) continue;
        if ((lp as dynamic).isFavorite == true) {
          add((lp as dynamic).productId.toString());
        }
      } catch (_) {}
    }
    for (final w in wish) {
      try {
        if ((w as dynamic).isFavorite == true) {
          add((w as dynamic).productId.toString());
        }
      } catch (_) {}
    }
    // 最近開啟
    final visible = lib.where((lp) {
      try {
        if ((lp as dynamic).isHidden == true) return false;
        return hotMap.containsKey((lp as dynamic).productId.toString());
      } catch (_) {
        return false;
      }
    }).toList();

    visible.sort((a, b) {
      DateTime ta;
      DateTime tb;
      try {
        ta = ((a as dynamic).lastOpenedAt as DateTime?) ??
            ((a as dynamic).purchasedAt as DateTime);
      } catch (_) {
        ta = DateTime.fromMillisecondsSinceEpoch(0);
      }
      try {
        tb = ((b as dynamic).lastOpenedAt as DateTime?) ??
            ((b as dynamic).purchasedAt as DateTime);
      } catch (_) {
        tb = DateTime.fromMillisecondsSinceEpoch(0);
      }
      return tb.compareTo(ta);
    });

    for (final lp in visible.take(3)) {
      try {
        add((lp as dynamic).productId.toString());
      } catch (_) {}
    }

    // 願望清單補
    for (final w in wish) {
      try {
        add((w as dynamic).productId.toString());
      } catch (_) {}
    }

    return result;
  }
}
