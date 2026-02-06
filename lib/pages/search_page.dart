import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/v2_providers.dart';
import '../widgets/app_card.dart';
import '../theme/app_tokens.dart';
import '../ui/rich_sections/user_state_store.dart';
import '../ui/rich_sections/search_history_section.dart';
import '../ui/rich_sections/search_suggestions_section.dart';
import 'product_page.dart';

// ✅ 若你專案有這個 provider（泡泡庫在用），就能做「已購買/推播中」篩選。
// 沒登入或不存在會自動 fallback，不會影響搜尋基本功能。
import '../bubble_library/providers/providers.dart' as v1;
import '../bubble_library/providers/providers.dart';
import '../collections/wishlist_provider.dart';

enum SearchSort { relevant, title, level }

class _SearchFilterState {
  final Set<String> topicIds; // 多選
  final Set<String> levels; // 多選
  final bool onlyPurchased;
  final bool onlyPushing;

  const _SearchFilterState({
    this.topicIds = const {},
    this.levels = const {},
    this.onlyPurchased = false,
    this.onlyPushing = false,
  });

  bool get isEmpty =>
      topicIds.isEmpty && levels.isEmpty && !onlyPurchased && !onlyPushing;

  _SearchFilterState copyWith({
    Set<String>? topicIds,
    Set<String>? levels,
    bool? onlyPurchased,
    bool? onlyPushing,
  }) {
    return _SearchFilterState(
      topicIds: topicIds ?? this.topicIds,
      levels: levels ?? this.levels,
      onlyPurchased: onlyPurchased ?? this.onlyPurchased,
      onlyPushing: onlyPushing ?? this.onlyPushing,
    );
  }
}

final _searchFilterProvider =
    StateProvider<_SearchFilterState>((ref) => const _SearchFilterState());

final _searchSortProvider =
    StateProvider<SearchSort>((ref) => SearchSort.relevant);

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _store = UserStateStore();
  final _searchController = TextEditingController();
  final _historyKey = GlobalKey<SearchHistorySectionState>();

  List<String> _recentCache = const [];

  @override
  void initState() {
    super.initState();
    _loadRecentCache();
  }

  Future<void> _loadRecentCache() async {
    try {
      final list = await _store.getRecentSearches();
      if (!mounted) return;
      setState(() => _recentCache = list.cast<String>());
    } catch (_) {
      if (!mounted) return;
      setState(() => _recentCache = const []);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submitSearch(String q) async {
    if (q.trim().isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await _store.addRecentSearch(q);
    ref.read(searchQueryProvider.notifier).state = q;
    ref.read(_searchFilterProvider.notifier).state = const _SearchFilterState();
    _searchController.text = q;
    _historyKey.currentState?.reload();
    await _loadRecentCache();
  }

  // ✅ 安全地取得「已購買/推播中」資訊（沒登入就回空）
  AsyncValue<List<dynamic>> _watchLibrarySafe(WidgetRef ref) {
    try {
      // 未登入會 throw（你專案 uidProvider 是這樣設計的）
      ref.read(v1.uidProvider);
      return ref
          .watch(v1.libraryProductsProvider)
          .whenData((list) => list.cast<dynamic>());
    } catch (_) {
      return const AsyncValue.data(<dynamic>[]);
    }
  }

  AsyncValue<List<dynamic>> _watchWishlistSafe(WidgetRef ref) {
    try {
      ref.read(v1.uidProvider);
      return ref
          .watch(localWishlistProvider)
          .whenData((list) => list.cast<dynamic>());
    } catch (_) {
      return const AsyncValue.data(<dynamic>[]);
    }
  }

  Set<String> _purchasedSetFromLib(List<dynamic> lib) {
    final s = <String>{};
    for (final lp in lib) {
      try {
        final pid = (lp as dynamic).productId as String?;
        if (pid != null) s.add(pid);
      } catch (_) {}
    }
    return s;
  }

  Set<String> _pushingSetFromLib(List<dynamic> lib) {
    final s = <String>{};
    for (final lp in lib) {
      try {
        final d = lp as dynamic;
        final pid = d.productId as String?;
        final pushing = (d.pushEnabled as bool?) ?? false;
        if (pid != null && pushing) s.add(pid);
      } catch (_) {}
    }
    return s;
  }

  List<String> _buildForYouKeywords({
    required List<String> recent,
    required List<dynamic> lib,
    required List<dynamic> wish,
    required Map<String, dynamic> productsMapDyn,
    int max = 10,
  }) {
    final out = <String>[];

    // 1) 最近搜尋：抽出高頻 token
    final freq = <String, int>{};
    for (final q in recent.take(30)) {
      final parts = q
          .replaceAll(RegExp(r'[^\w\u4e00-\u9fff ]'), ' ')
          .split(RegExp(r'\s+'))
          .map((e) => e.trim())
          .where((e) => e.length >= 2)
          .toList();
      for (final p in parts) {
        freq[p] = (freq[p] ?? 0) + 1;
      }
    }
    final hotTokens = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in hotTokens.take(5)) {
      out.add(e.key);
    }

    // 2) 收藏/最愛/推播中 → 推 topicId
    final topicFreq = <String, int>{};
    void bumpTopicFromProductId(String? pid, {int w = 1}) {
      if (pid == null) return;
      final p = productsMapDyn[pid];
      if (p == null) return;
      try {
        final tid = (p as dynamic).topicId?.toString();
        if (tid == null || tid.isEmpty) return;
        topicFreq[tid] = (topicFreq[tid] ?? 0) + w;
      } catch (_) {}
    }

    for (final lp in lib) {
      try {
        final d = lp as dynamic;
        final pid = d.productId as String?;
        final fav = (d.isFavorite as bool?) ?? false;
        final pushing = (d.pushEnabled as bool?) ?? false;
        if (fav) bumpTopicFromProductId(pid, w: 3);
        if (pushing) bumpTopicFromProductId(pid, w: 2);
      } catch (_) {}
    }
    for (final w in wish) {
      try {
        final d = w as dynamic;
        final pid = d.productId as String?;
        final fav = (d.isFavorite as bool?) ?? false;
        if (fav) bumpTopicFromProductId(pid, w: 2);
      } catch (_) {}
    }
    final topTopics = topicFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in topTopics.take(4)) {
      out.add(e.key);
    }

    // 去重 + 限量
    final seen = <String>{};
    final dedup = <String>[];
    for (final k in out) {
      final kk = k.trim();
      if (kk.isEmpty) continue;
      if (seen.add(kk)) dedup.add(kk);
      if (dedup.length >= max) break;
    }
    return dedup;
  }

  List<dynamic> _applyFiltersAndSort({
    required List<dynamic> products,
    required _SearchFilterState filter,
    required SearchSort sort,
    required Set<String> purchasedSet,
    required Set<String> pushingSet,
  }) {
    Iterable<dynamic> list = products;

    // filters（比對時 trim，與 sheet 萃取一致）
    if (filter.topicIds.isNotEmpty) {
      list = list.where((p) {
        final tid = ((p as dynamic).topicId?.toString() ?? '').trim();
        return tid.isNotEmpty && filter.topicIds.contains(tid);
      });
    }
    if (filter.levels.isNotEmpty) {
      list = list.where((p) {
        final lv = ((p as dynamic).level?.toString() ?? '').trim();
        return lv.isNotEmpty && filter.levels.contains(lv);
      });
    }
    if (filter.onlyPurchased) {
      list = list.where((p) => purchasedSet.contains((p as dynamic).id));
    }
    if (filter.onlyPushing) {
      list = list.where((p) => pushingSet.contains((p as dynamic).id));
    }

    final out = list.toList();

    // sort
    if (sort == SearchSort.title) {
      out.sort((a, b) {
        final ta = ((a as dynamic).title ?? '').toString();
        final tb = ((b as dynamic).title ?? '').toString();
        return ta.compareTo(tb);
      });
    } else if (sort == SearchSort.level) {
      out.sort((a, b) {
        final la = ((a as dynamic).level ?? '').toString();
        final lb = ((b as dynamic).level ?? '').toString();
        return la.compareTo(lb);
      });
    } // relevant: keep original order

    return out;
  }

  Future<void> _openFilterSheet({
    required BuildContext context,
    required List<dynamic> products,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final tokens = context.tokens;
    final cur = ref.read(_searchFilterProvider);

    // 從「目前結果」萃取可選項（trim 以利後續精確比對）
    final topicIds = <String>{};
    final levels = <String>{};
    for (final p in products) {
      final tid = ((p as dynamic).topicId?.toString() ?? '').trim();
      final lv = ((p as dynamic).level?.toString() ?? '').trim();
      if (tid.isNotEmpty) topicIds.add(tid);
      if (lv.isNotEmpty) levels.add(lv);
    }
    final topicList = topicIds.toList()..sort();
    final levelList = levels.toList()..sort();

    // draft 必須跨 rebuild 保留，否則點 chip 後 setState 會把 draft 重置為 cur
    final draftNotifier = ValueNotifier<_SearchFilterState>(cur);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF14182E)
                : tokens.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: tokens.cardBorder),
          ),
          child: ValueListenableBuilder<_SearchFilterState>(
            valueListenable: draftNotifier,
            builder: (context, draft, _) {
              Widget chips({
                required List<String> items,
                required Set<String> selected,
                required void Function(String v) onToggle,
              }) {
                if (items.isEmpty) {
                  return Text('(No options)',
                      style: TextStyle(color: tokens.textSecondary));
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: items.map((v) {
                    final sel = selected.contains(v);
                    return FilterChip(
                      selected: sel,
                      label: Text(v),
                      onSelected: (_) => onToggle(v),
                      selectedColor: tokens.primary.withValues(alpha: 0.15),
                      checkmarkColor: tokens.primary,
                      labelStyle: TextStyle(
                        color: sel ? tokens.primary : tokens.textPrimary,
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                      ),
                      side: BorderSide(
                          color: sel ? tokens.primary : tokens.cardBorder),
                      backgroundColor: tokens.chipBg,
                    );
                  }).toList(),
                );
              }

              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Filters',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: tokens.textPrimary)),
                        const Spacer(),
                        TextButton(
                          onPressed: () =>
                              draftNotifier.value = const _SearchFilterState(),
                          child: const Text('Clear'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            ref.read(_searchFilterProvider.notifier).state =
                                draftNotifier.value;
                            Navigator.of(context).pop();
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: draft.onlyPurchased,
                      onChanged: (v) =>
                          draftNotifier.value = draft.copyWith(onlyPurchased: v),
                      title: Text('Purchased only',
                          style: TextStyle(color: tokens.textPrimary)),
                      subtitle: Text('Sign in to filter by purchase',
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: draft.onlyPushing,
                      onChanged: (v) =>
                          draftNotifier.value = draft.copyWith(onlyPushing: v),
                      title: Text('Notifications on only',
                          style: TextStyle(color: tokens.textPrimary)),
                      subtitle: Text('Purchased and notifications enabled',
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                    const SizedBox(height: 12),
                    Text('Category (topicId)',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: tokens.textPrimary)),
                    const SizedBox(height: 8),
                    chips(
                      items: topicList,
                      selected: draft.topicIds,
                      onToggle: (v) {
                        final next = {...draft.topicIds};
                        next.contains(v) ? next.remove(v) : next.add(v);
                        draftNotifier.value = draft.copyWith(topicIds: next);
                      },
                    ),
                    const SizedBox(height: 14),
                    Text('Level',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: tokens.textPrimary)),
                    const SizedBox(height: 8),
                    chips(
                      items: levelList,
                      selected: draft.levels,
                      onToggle: (v) {
                        final next = {...draft.levels};
                        next.contains(v) ? next.remove(v) : next.add(v);
                        draftNotifier.value = draft.copyWith(levels: next);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final tokens = context.tokens;

    final filter = ref.watch(_searchFilterProvider);
    final sort = ref.watch(_searchSortProvider);

    // ✅ library 只用於「已購買/推播中」篩選與顯示，不會影響基本搜尋
    final libAsync = _watchLibrarySafe(ref);
    final libAsync2 = ref.watch(libraryProductsProvider);
    final wishAsync = ref.watch(localWishlistProvider);

    final ownedFilter = ref.watch(searchOwnedFilterProvider);
    final pushFilter = ref.watch(searchPushFilterProvider);
    final wishFilter = ref.watch(searchWishFilterProvider);
    final levelFilter = ref.watch(searchLevelFilterProvider);

    return SafeArea(
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Container(
                decoration: BoxDecoration(
                  gradient: tokens.searchBarGradient,
                  borderRadius: BorderRadius.circular(tokens.cardRadius),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(color: tokens.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search products or topics…',
                    hintStyle: TextStyle(color: tokens.textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    icon: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Icon(Icons.search, color: tokens.textSecondary),
                    ),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon:
                                Icon(Icons.clear, color: tokens.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(searchQueryProvider.notifier).state = '';
                              ref.read(_searchFilterProvider.notifier).state =
                                  const _SearchFilterState();
                              ref.read(_searchSortProvider.notifier).state =
                                  SearchSort.relevant;
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) =>
                      ref.read(searchQueryProvider.notifier).state = value,
                  onSubmitted: _submitSearch,
                ),
              ),
            ),
          ),
          // Body
          Expanded(
            child: results.when(
              data: (productsRaw) {
                // query empty → show history + suggestions
                if (query.isEmpty) {
                  final wishAsync = _watchWishlistSafe(ref);
                  final wish = wishAsync.valueOrNull ?? const <dynamic>[];
                  final lib = libAsync.valueOrNull ?? const <dynamic>[];

                  Map<String, dynamic> productsMapDyn = {};
                  try {
                    final pmAsync = ref.watch(v1.productsMapProvider);
                    productsMapDyn = pmAsync.when(
                      data: (m) => m.map((k, v) => MapEntry(k, v as dynamic)),
                      loading: () => <String, dynamic>{},
                      error: (_, __) => <String, dynamic>{},
                    );
                  } catch (_) {}

                  final forYou = _buildForYouKeywords(
                    recent: _recentCache,
                    lib: lib,
                    wish: wish,
                    productsMapDyn: productsMapDyn,
                  );

                  return ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: SearchHistorySection(
                          key: _historyKey,
                          onTapQuery: (q) => _submitSearch(q),
                        ),
                      ),
                      SearchForYouSection(
                        keywords: forYou,
                        onRefresh: _loadRecentCache,
                        onTap: (q) => _submitSearch(q),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: SearchSuggestionsSection(
                          onTap: (q) => _submitSearch(q),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                }

                final products = productsRaw.cast<dynamic>();

                final lib = libAsync.valueOrNull ?? const <dynamic>[];
                final purchasedSetOld = _purchasedSetFromLib(lib);
                final pushingSetOld = _pushingSetFromLib(lib);

                // ✅ 新的 filter sets（用於新的 filter chips）
                final purchasedSet = <String>{};
                final pushingSet = <String>{};
                final wishedSet = <String>{};

                libAsync2.whenData((lib) {
                  for (final lp in lib) {
                    if (lp.isHidden) continue;
                    purchasedSet.add(lp.productId);
                    if (lp.pushEnabled) pushingSet.add(lp.productId);
                  }
                });

                wishAsync.whenData((wish) {
                  for (final w in wish) {
                    wishedSet.add(w.productId);
                  }
                });

                // ✅ 先套用新的 filters
                List filtered = products;

                if (ownedFilter == SearchOwnedFilter.purchased) {
                  filtered = filtered.where((p) => purchasedSet.contains(p.id)).toList();
                } else if (ownedFilter == SearchOwnedFilter.notPurchased) {
                  filtered = filtered.where((p) => !purchasedSet.contains(p.id)).toList();
                }

                if (pushFilter == SearchPushFilter.pushingOnly) {
                  filtered = filtered.where((p) => pushingSet.contains(p.id)).toList();
                }

                if (wishFilter == SearchWishFilter.wishedOnly) {
                  filtered = filtered.where((p) => wishedSet.contains(p.id)).toList();
                }

                bool matchLevel(dynamic p) {
                  final lv = (p.level ?? '').toString().toLowerCase();
                  switch (levelFilter) {
                    case SearchLevelFilter.all:
                      return true;
                    case SearchLevelFilter.foundation:
                      return lv.contains('foundation');
                    case SearchLevelFilter.practical:
                      return lv.contains('practical');
                    case SearchLevelFilter.deepDive:
                      return lv.contains('deep');
                    case SearchLevelFilter.specialized:
                      return lv.contains('specialized');
                  }
                }

                filtered = filtered.where(matchLevel).toList();

                // ✅ 再套用舊的 filters 和 sort（保留原有功能）
                filtered = _applyFiltersAndSort(
                  products: filtered,
                  filter: filter,
                  sort: sort,
                  purchasedSet: purchasedSetOld,
                  pushingSet: pushingSetOld,
                );

                // ✅ Filters（只有在有 query 時顯示）
                Widget filtersBar() {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        FilterChip(
                          selected: ownedFilter == SearchOwnedFilter.purchased,
                          label: const Text('Purchased'),
                          onSelected: (v) => ref.read(searchOwnedFilterProvider.notifier).state =
                              v ? SearchOwnedFilter.purchased : SearchOwnedFilter.all,
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: pushFilter == SearchPushFilter.pushingOnly,
                          label: const Text('Notifications on'),
                          onSelected: (v) => ref.read(searchPushFilterProvider.notifier).state =
                              v ? SearchPushFilter.pushingOnly : SearchPushFilter.all,
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: wishFilter == SearchWishFilter.wishedOnly,
                          label: const Text('Bookmarked'),
                          onSelected: (v) => ref.read(searchWishFilterProvider.notifier).state =
                              v ? SearchWishFilter.wishedOnly : SearchWishFilter.all,
                        ),
                        const SizedBox(width: 8),
                        _LevelChip(
                          current: levelFilter,
                          onChange: (next) =>
                              ref.read(searchLevelFilterProvider.notifier).state = next,
                        ),
                      ],
                    ),
                  );
                }

                // ✅ 篩選/排序控制列
                Widget filterBar() {
                  final hasActive =
                      !filter.isEmpty || sort != SearchSort.relevant;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Flexible(
                            child: OutlinedButton.icon(
                              onPressed: () => _openFilterSheet(
                                  context: context, products: products),
                              icon: const Icon(Icons.tune),
                              label: Text(
                                hasActive ? 'Filters (applied)' : 'Filters',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<SearchSort>(
                                  value: sort,
                                  // ✅ 修復深色主題下拉選單透明背景重疊問題
                                  dropdownColor: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF14182E)
                                      : null,
                                  items: const [
                                    DropdownMenuItem(
                                      value: SearchSort.relevant,
                                      child: Text('Sort: Relevance'),
                                    ),
                                    DropdownMenuItem(
                                      value: SearchSort.title,
                                      child: Text('Sort: Title'),
                                    ),
                                    DropdownMenuItem(
                                      value: SearchSort.level,
                                      child: Text('Sort: Level'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    ref
                                        .read(_searchSortProvider.notifier)
                                        .state = v;
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (products.isEmpty) {
                  return Column(
                    children: [
                      filterBar(),
                      Expanded(
                        child: Center(
                          child: Text('No results for "$query"',
                              style: TextStyle(
                                  fontSize: 16, color: tokens.textSecondary)),
                        ),
                      ),
                    ],
                  );
                }

                if (filtered.isEmpty) {
                  return Column(
                    children: [
                      filterBar(),
                      const SizedBox(height: 4),
                      filtersBar(),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Center(
                          child: Text('Filters applied, but no matching results',
                              style: TextStyle(
                                  fontSize: 16, color: tokens.textSecondary)),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    filterBar(),
                    const SizedBox(height: 4),
                    filtersBar(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          final product = filtered[index] as dynamic;
                          final pid = product.id as String;
                          final isPurchased = purchasedSet.contains(pid);
                          final isPushing = pushingSet.contains(pid);

                          return AppCard(
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ProductPage(productId: pid))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        (product.title ?? '').toString(),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: tokens.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (isPurchased)
                                      _pill(
                                          'Purchased',
                                          tokens.primary
                                              .withValues(alpha: 0.16),
                                          tokens.primary),
                                    if (isPushing) ...[
                                      const SizedBox(width: 6),
                                      _pill(
                                          'Notifications on',
                                          tokens.primary
                                              .withValues(alpha: 0.12),
                                          tokens.primary),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${product.topicId} · ${product.level}',
                                  style: TextStyle(color: tokens.textSecondary),
                                ),
                                finalLG(product, tokens),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Search error:',
                            style: TextStyle(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          '$error',
                          style: TextStyle(
                              color: tokens.textSecondary, fontSize: 12),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget finalLG(dynamic product, AppTokens tokens) {
    final lg = (product.levelGoal as String?)?.trim();
    if (lg == null || lg.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        lg,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: tokens.textSecondary),
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(text,
          style:
              TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class SearchForYouSection extends StatelessWidget {
  final List<String> keywords;
  final VoidCallback onRefresh;
  final void Function(String q) onTap;

  const SearchForYouSection({
    super.key,
    required this.keywords,
    required this.onRefresh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (keywords.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('You might like',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    )),
                const Spacer(),
                TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: keywords
                  .map((k) => ActionChip(
                        label: Text(k),
                        onPressed: () => onTap(k),
                        backgroundColor: tokens.chipBg,
                        labelStyle: TextStyle(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(color: tokens.cardBorder),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final SearchLevelFilter current;
  final ValueChanged<SearchLevelFilter> onChange;

  const _LevelChip({required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) {
    String label;
    switch (current) {
      case SearchLevelFilter.all:
        label = 'Level';
        break;
      case SearchLevelFilter.foundation:
        label = 'Foundation';
        break;
      case SearchLevelFilter.practical:
        label = 'Practical';
        break;
      case SearchLevelFilter.deepDive:
        label = 'Deep Dive';
        break;
      case SearchLevelFilter.specialized:
        label = 'Specialized';
        break;
    }

    return PopupMenuButton<SearchLevelFilter>(
      onSelected: onChange,
      itemBuilder: (_) => const [
        PopupMenuItem(value: SearchLevelFilter.all, child: Text('All Levels')),
        PopupMenuItem(value: SearchLevelFilter.foundation, child: Text('Foundation')),
        PopupMenuItem(value: SearchLevelFilter.practical, child: Text('Practical')),
        PopupMenuItem(value: SearchLevelFilter.deepDive, child: Text('Deep Dive')),
        PopupMenuItem(value: SearchLevelFilter.specialized, child: Text('Specialized')),
      ],
      child: Chip(
        label: Text(label),
      ),
    );
  }
}
