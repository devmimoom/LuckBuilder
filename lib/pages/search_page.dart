import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/v2_providers.dart';
import '../widgets/app_card.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../theme/layout_constants.dart';
import '../data/models.dart';
import '../ui/rich_sections/user_state_store.dart';
import '../ui/rich_sections/search_history_section.dart';
import '../ui/rich_sections/search_suggestions_section.dart';
import 'product_page.dart';
import 'product_list_page.dart';
import '../localization/app_language_provider.dart';
import '../localization/app_language.dart';
import '../localization/bilingual_text.dart';
import '../localization/app_strings.dart';

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
    final lang = ref.read(appLanguageProvider);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(kPageHorizontalPadding, AppSpacing.sm, kPageHorizontalPadding, AppSpacing.sm),
          decoration: BoxDecoration(
            color: tokens.cardBg,
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
                        Text(uiString(lang, 'filters'),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: tokens.textPrimary)),
                        const Spacer(),
                        TextButton(
                          onPressed: () =>
                              draftNotifier.value = const _SearchFilterState(),
                          child: Text(uiString(lang, 'clear')),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            ref.read(_searchFilterProvider.notifier).state =
                                draftNotifier.value;
                            Navigator.of(context).pop();
                          },
                          child: Text(uiString(lang, 'apply')),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: draft.onlyPurchased,
                      onChanged: (v) =>
                          draftNotifier.value = draft.copyWith(onlyPurchased: v),
                      title: Text(uiString(lang, 'purchased_only'),
                          style: TextStyle(color: tokens.textPrimary)),
                      subtitle: Text(uiString(lang, 'purchased_only_sub'),
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: draft.onlyPushing,
                      onChanged: (v) =>
                          draftNotifier.value = draft.copyWith(onlyPushing: v),
                      title: Text(uiString(lang, 'notifications_on_only'),
                          style: TextStyle(color: tokens.textPrimary)),
                      subtitle: Text(
                          uiString(lang, 'notifications_on_only_sub'),
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(uiString(lang, 'category_label'),
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
                    const SizedBox(height: AppSpacing.sm),
                    Text(uiString(lang, 'level_label_filters'),
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
    final lang = ref.watch(appLanguageProvider);

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
                    hintText: uiString(lang, 'search_products_or_topics_placeholder'),
                    hintStyle: TextStyle(color: tokens.textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: AppSpacing.sm),
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
                      const Padding(
                        padding: EdgeInsets.fromLTRB(kPageHorizontalPadding, AppSpacing.xs, kPageHorizontalPadding, AppSpacing.sm),
                        child: _SearchExploreCard(),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(kPageHorizontalPadding, AppSpacing.xs, kPageHorizontalPadding, AppSpacing.sm),
                        child: AppCard(
                          child: SearchHistorySection(
                            key: _historyKey,
                            onTapQuery: (q) => _submitSearch(q),
                          ),
                        ),
                      ),
                      SearchForYouSection(
                        keywords: forYou,
                        onRefresh: _loadRecentCache,
                        onTap: (q) => _submitSearch(q),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(kPageHorizontalPadding, AppSpacing.xs, kPageHorizontalPadding, AppSpacing.sm),
                        child: AppCard(
                          child: SearchSuggestionsSection(
                            onTap: (q) => _submitSearch(q),
                          ),
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
                    padding: const EdgeInsets.symmetric(horizontal: kPageHorizontalPadding),
                    child: Row(
                      children: [
                        FilterChip(
                          selected: ownedFilter == SearchOwnedFilter.purchased,
                          label: Text(uiString(lang, 'purchased_label')),
                          onSelected: (v) => ref.read(searchOwnedFilterProvider.notifier).state =
                              v ? SearchOwnedFilter.purchased : SearchOwnedFilter.all,
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: pushFilter == SearchPushFilter.pushingOnly,
                          label: Text(uiString(lang, 'notifications_on')),
                          onSelected: (v) => ref.read(searchPushFilterProvider.notifier).state =
                              v ? SearchPushFilter.pushingOnly : SearchPushFilter.all,
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: wishFilter == SearchWishFilter.wishedOnly,
                          label: Text(uiString(lang, 'bookmarked_title')),
                          onSelected: (v) => ref.read(searchWishFilterProvider.notifier).state =
                              v ? SearchWishFilter.wishedOnly : SearchWishFilter.all,
                        ),
                        const SizedBox(width: 8),
                        _LevelChip(
                          lang: lang,
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
                    padding: const EdgeInsets.fromLTRB(kPageHorizontalPadding, 0, kPageHorizontalPadding, AppSpacing.sm),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                      child: Row(
                        children: [
                          Flexible(
                            child: OutlinedButton.icon(
                              onPressed: () => _openFilterSheet(
                                  context: context, products: products),
                              icon: const Icon(Icons.tune),
                              label: Text(
                                hasActive
                                    ? uiString(lang, 'filters_applied')
                                    : uiString(lang, 'filters'),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<SearchSort>(
                                  value: sort,
                                  // ✅ 修復深色主題下拉選單透明背景重疊問題
                                  dropdownColor: tokens.cardBg,
                                  items: [
                                    DropdownMenuItem(
                                      value: SearchSort.relevant,
                                      child: Text(uiString(lang, 'sort_relevance')),
                                    ),
                                    DropdownMenuItem(
                                      value: SearchSort.title,
                                      child: Text(uiString(lang, 'sort_title')),
                                    ),
                                    DropdownMenuItem(
                                      value: SearchSort.level,
                                      child: Text(uiString(lang, 'sort_level')),
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
                          child: Text(uiString(lang, 'no_results_for_query').replaceFirst('{query}', query),
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
                      const SizedBox(height: AppSpacing.xs),
                      filtersBar(),
                      const SizedBox(height: AppSpacing.xs),
                      Expanded(
                        child: Center(
                          child: Text(uiString(lang, 'filters_no_match'),
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
                    const SizedBox(height: AppSpacing.xs),
                    filtersBar(),
                    const SizedBox(height: AppSpacing.xs),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: kPageHorizontalPadding),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, index) {
                          final product = filtered[index] as Product;
                          final pid = product.id;
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
                                  productTitle(product, lang),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                                    ),
                                    if (isPurchased)
                                      _pill(
                                          uiString(lang, 'purchased_label'),
                                          tokens.primary
                                              .withValues(alpha: 0.16),
                                          tokens.primary),
                                    if (isPushing) ...[
                                      const SizedBox(width: AppSpacing.xs),
                                      _pill(
                                          uiString(lang, 'notifications_on'),
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
                                finalLG(product, tokens, lang),
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
                        Text(uiString(lang, 'search_error'),
                            style: TextStyle(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: AppSpacing.xs),
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

  Widget finalLG(Product product, AppTokens tokens, AppLanguage lang) {
    final lg = productLevelGoal(product, lang).trim();
    if (lg.isEmpty) return const SizedBox.shrink();
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
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

class SearchForYouSection extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final lang = ref.watch(appLanguageProvider);
    if (keywords.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPageHorizontalPadding, AppSpacing.xs, kPageHorizontalPadding, AppSpacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(uiString(lang, 'you_might_like'),
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    )),
                const Spacer(),
                TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(uiString(lang, 'refresh')),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
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

class _SearchExploreCard extends ConsumerWidget {
  const _SearchExploreCard();

  AsyncValue<List<dynamic>> _safeLib(WidgetRef ref) {
    try {
      ref.read(v1.uidProvider);
      return ref.watch(v1.libraryProductsProvider).whenData((l) => l.cast<dynamic>());
    } catch (_) {
      return const AsyncValue.data(<dynamic>[]);
    }
  }

  AsyncValue<List<dynamic>> _safeWish(WidgetRef ref) {
    try {
      ref.read(v1.uidProvider);
      return ref.watch(localWishlistProvider).whenData((l) => l.cast<dynamic>());
    } catch (_) {
      return const AsyncValue.data(<dynamic>[]);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final lang = ref.watch(appLanguageProvider);
    final productsMapAsync = ref.watch(allProductsMapProvider);
    final libAsync = _safeLib(ref);
    final wishAsync = _safeWish(ref);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: productsMapAsync.when(
        data: (productsMap) {
          return libAsync.when(
            data: (lib) {
              return wishAsync.when(
                data: (wish) {
                  final recentTopics =
                      _recentTopicIds(productsMap, lib).take(3).toList();
                  final maybeTry =
                      _maybeTryTopicIds(productsMap, lib, wish).take(3).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(uiString(lang, 'recently_viewed'),
                          style: TextStyle(
                              color: tokens.textSecondary,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      if (recentTopics.isEmpty)
                        Text(
                            uiString(lang, 'search_recent_empty_hint'),
                            style: TextStyle(color: tokens.textSecondary))
                      else
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: recentTopics
                              .map((t) => _chip(context, t, onTap: () {
                                    Navigator.of(context).push(MaterialPageRoute(
                                        builder: (_) =>
                                            ProductListPage(topicId: t)));
                                  }))
                              .toList(),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(uiString(lang, 'you_might_like'),
                          style: TextStyle(
                              color: tokens.textSecondary,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      if (maybeTry.isEmpty)
                        Text(
                            uiString(lang, 'search_wishlist_hint'),
                            style: TextStyle(color: tokens.textSecondary))
                      else
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: maybeTry
                              .map((t) => _chip(context, t, onTap: () {
                                    Navigator.of(context).push(MaterialPageRoute(
                                        builder: (_) =>
                                            ProductListPage(topicId: t)));
                                  }))
                              .toList(),
                        ),
                    ],
                  );
                },
                loading: () => const SizedBox(
                    height: 64,
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('${uiString(lang, 'wishlist_error')}$e',
                    style: TextStyle(color: tokens.textSecondary)),
              );
            },
            loading: () => const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('${uiString(lang, 'library_error')}$e',
                style: TextStyle(color: tokens.textSecondary)),
          );
        },
        loading: () => const SizedBox(
            height: 64, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(
          uiString(lang, 'suggestions_load_error'),
          style: TextStyle(color: tokens.textSecondary),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text, {required VoidCallback onTap}) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: tokens.chipBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tokens.cardBorder),
        ),
        child: Text(text,
            style: TextStyle(color: tokens.textPrimary, fontSize: 12)),
      ),
    );
  }
}

List<String> _recentTopicIds(Map<String, Product> productsMap, List<dynamic> lib) {
  final items = lib.where((lp) {
    try {
      if ((lp as dynamic).isHidden == true) return false;
      return productsMap.containsKey((lp as dynamic).productId.toString());
    } catch (_) {
      return false;
    }
  }).toList();

  items.sort((a, b) {
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

  final seen = <String>{};
  final out = <String>[];
  for (final lp in items) {
    final pid = (lp as dynamic).productId.toString();
    final p = productsMap[pid];
    if (p == null) continue;
    final tid = p.topicId;
    if (seen.add(tid)) out.add(tid);
    if (out.length >= 6) break;
  }
  return out;
}

List<String> _maybeTryTopicIds(
    Map<String, Product> productsMap, List<dynamic> lib, List<dynamic> wish) {
  final recent = _recentTopicIds(productsMap, lib).toSet();
  final count = <String, int>{};

  for (final w in wish) {
    try {
      final pid = (w as dynamic).productId.toString();
      final p = productsMap[pid];
      if (p == null) continue;
      final tid = p.topicId;
      if (recent.contains(tid)) continue;
      count[tid] = (count[tid] ?? 0) + 1;
    } catch (_) {}
  }

  final list = count.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return list.map((e) => e.key).toList();
}

class _LevelChip extends StatelessWidget {
  final AppLanguage lang;
  final SearchLevelFilter current;
  final ValueChanged<SearchLevelFilter> onChange;

  const _LevelChip({required this.lang, required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) {
    String label;
    switch (current) {
      case SearchLevelFilter.all:
        label = uiString(lang, 'level_filter_all');
        break;
      case SearchLevelFilter.foundation:
        label = uiString(lang, 'level_foundation');
        break;
      case SearchLevelFilter.practical:
        label = uiString(lang, 'level_practical');
        break;
      case SearchLevelFilter.deepDive:
        label = uiString(lang, 'level_deep_dive');
        break;
      case SearchLevelFilter.specialized:
        label = uiString(lang, 'level_specialized');
        break;
    }

    return PopupMenuButton<SearchLevelFilter>(
      onSelected: onChange,
      itemBuilder: (_) => [
        PopupMenuItem(value: SearchLevelFilter.all, child: Text(uiString(lang, 'all_levels'))),
        PopupMenuItem(value: SearchLevelFilter.foundation, child: Text(uiString(lang, 'level_foundation'))),
        PopupMenuItem(value: SearchLevelFilter.practical, child: Text(uiString(lang, 'level_practical'))),
        PopupMenuItem(value: SearchLevelFilter.deepDive, child: Text(uiString(lang, 'level_deep_dive'))),
        PopupMenuItem(value: SearchLevelFilter.specialized, child: Text(uiString(lang, 'level_specialized'))),
      ],
      child: Chip(
        label: Text(label),
      ),
    );
  }
}
