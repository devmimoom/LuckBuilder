import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/product.dart';
import '../models/user_library.dart';
import '../models/content_item.dart';
import '../notifications/scheduled_push_cache.dart';
import '../notifications/push_orchestrator.dart';
import '../../notifications/push_timeline_provider.dart';
import '../../localization/app_language.dart';
import '../../localization/app_language_provider.dart';
import '../../localization/app_strings.dart';
import 'product_library_page.dart';
import 'push_center_page.dart';
import 'push_product_config_page.dart';
import 'detail_page.dart';
import 'widgets/bubble_card.dart';
import '../../widgets/rich_sections/sections/library_rich_card.dart';
import '../../widgets/rich_sections/user_learning_store.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_tokens.dart';
import '../../collections/wishlist_provider.dart';
import '../../pages/product_page.dart';
import '../../notifications/favorite_sentences_store.dart';

enum LibraryView { purchased, wishlist, favorites, history, favoriteSentences }

enum PurchasedPushFilter { all, pushing, off }

class BubbleLibraryPage extends ConsumerStatefulWidget {
  const BubbleLibraryPage({super.key});

  @override
  ConsumerState<BubbleLibraryPage> createState() => _BubbleLibraryPageState();
}

class _BubbleLibraryPageState extends ConsumerState<BubbleLibraryPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  LibraryView currentView = LibraryView.purchased;
  DateTime? _lastRescheduleTime;

  final Set<String> _selectedProductIds = {};
  int _selectedHistoryTab = 0; // 0 = 待學習, 1 = 已學習

  // 已購買清單篩選狀態
  final Set<String> _purchasedTopicIds = {};
  final Set<String> _purchasedLevels = {};
  PurchasedPushFilter _purchasedPushFilter = PurchasedPushFilter.all;
  String _purchasedSearchQuery = '';

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final lang = ref.watch(appLanguageProvider);
    final productsAsync = ref.watch(productsMapProvider);

    // 檢查是否登入，未登入時顯示提示
    try {
      ref.read(uidProvider);
    } catch (_) {
      return Scaffold(
        backgroundColor: tokens.bg,
        appBar: AppBar(
          title: Text(uiString(lang, 'my_library')),
          backgroundColor: tokens.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: Center(
          child: Text(uiString(lang, 'library_sign_in_hint')),
        ),
      );
    }

    final libAsync = ref.watch(libraryProductsProvider);
    final wishAsync = ref.watch(localWishlistProvider);
    final scheduledAsync = ref.watch(scheduledCacheProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: tokens.bg,
      appBar: AppBar(
        title: Text(uiString(lang, 'my_library')),
        backgroundColor: tokens.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PushCenterPage())),
          ),
        ],
      ),
      drawer: _buildDrawer(lang),
      body: productsAsync.when(
        data: (productsMap) {
          return libAsync.when(
            data: (lib) {
              return wishAsync.when(
                data: (wishItems) {
                  final visibleLib = lib
                      .where((e) =>
                          !e.isHidden &&
                          productsMap.containsKey(e.productId))
                      .toList();

                  // 取得排程快取（純本機，不影響資料流）
                  final scheduled = scheduledAsync.asData?.value ??
                      <ScheduledPushEntry>[];

                  return _buildBody(
                    context,
                    visibleLib,
                    wishItems,
                    productsMap,
                    scheduled,
                    lang,
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('${uiString(lang, 'wishlist_error')}$e'),
                ),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                uiString(lang, 'library_load_error'),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            uiString(lang, 'content_load_error'),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(AppLanguage lang) {
    final tokens = context.tokens;
    return Drawer(
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(AppSpacing.radiusMd),
          bottomRight: Radius.circular(AppSpacing.radiusMd),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: tokens.bgGradient,
            color: tokens.bgGradient == null ? tokens.bg : null,
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xxl, AppSpacing.md, AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: tokens.cardBorder, width: 1),
                  ),
                ),
                child: Text(
                  uiString(lang, 'my_library'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                child: Column(
                  children: [
                    _drawerTile(tokens, LibraryView.purchased,
                        Icons.inventory_2, uiString(lang, 'purchased_label')),
                    _drawerTile(
                        tokens,
                        LibraryView.wishlist,
                        Icons.bookmark_border,
                        uiString(lang, 'dashboard_bookmarked')),
                    _drawerTile(
                        tokens,
                        LibraryView.favorites,
                        Icons.star_border,
                        uiString(lang, 'dashboard_favorites')),
                    _drawerTile(
                        tokens,
                        LibraryView.history,
                        Icons.history_edu,
                        uiString(lang, 'recently_opened')),
                    _drawerTile(
                        tokens,
                        LibraryView.favoriteSentences,
                        Icons.format_quote,
                        uiString(lang, 'saved_bites')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ListTile _drawerTile(AppTokens tokens, LibraryView view, IconData icon, String title) {
    final selected = currentView == view;
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? tokens.primary : tokens.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: selected ? tokens.primary : tokens.textPrimary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: selected,
      selectedTileColor: tokens.primary.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: () {
        Navigator.pop(context);
        setState(() => currentView = view);
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<UserLibraryProduct> visibleLib,
    List<WishlistItem> wishItems,
    Map<String, Product> productsMap,
    List<ScheduledPushEntry> scheduled,
    AppLanguage lang,
  ) {
    switch (currentView) {
      case LibraryView.purchased:
        return _buildPurchasedTab(
            context, visibleLib, productsMap, scheduled, lang);
      case LibraryView.wishlist:
        return _buildWishlistTab(context, wishItems, productsMap, visibleLib, lang);
      case LibraryView.favorites:
        return _buildFavoritesTab(context, visibleLib, wishItems, productsMap, lang);
      case LibraryView.history:
        return _buildHistoryView(context, lang);
      case LibraryView.favoriteSentences:
        return _buildFavoriteSentencesTab(context);
    }
  }

  Widget _buildPurchasedTab(
    BuildContext context,
    List<dynamic> visibleLib,
    Map<String, Product> productsMap,
    List<ScheduledPushEntry> scheduled,
    AppLanguage lang,
  ) {
    // Helper: 根據 productId 找最早的排程項目
    ScheduledPushEntry? nextEntryFor(String productId) {
      final list = scheduled
          .where((s) => s.payload['productId']?.toString() == productId)
          .toList();
      if (list.isEmpty) return null;
      list.sort((a, b) => a.when.compareTo(b.when));
      return list.first;
    }

    String fmtNextTime(DateTime dt) {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    String? extractDayFromBody(String body) {
      final firstLine = body.split('\n').first;
      final m = RegExp(r'Day\s+(\d+)/365').firstMatch(firstLine);
      return m?.group(1);
    }

    String latestTitleText(ScheduledPushEntry e) {
      // Day from payload first (body no longer contains Day N/365)
      final pushOrder = e.payload['pushOrder'];
      final day = pushOrder is int
          ? pushOrder.toString()
          : (pushOrder is num ? pushOrder.toInt().toString() : null) ??
              extractDayFromBody(e.body);
      final nextPrefix = uiString(lang, 'next_push_time').replaceFirst('{time}', '');
      return day == null ? '$nextPrefix${e.title}' : '$nextPrefix${e.title} (#$day)';
    }

    final tokens = context.tokens;

    if (visibleLib.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: tokens.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              uiString(lang, 'no_purchased_yet'),
              style: TextStyle(
                  color: tokens.textPrimary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // 套用篩選：主題、等級、推播狀態、關鍵字
    final filtered = visibleLib.where((e) {
      final lp = e as UserLibraryProduct;
      final product = productsMap[lp.productId];
      if (product == null) { return false; }
      if (_purchasedTopicIds.isNotEmpty &&
          !_purchasedTopicIds.contains(product.topicId)) { return false; }
      if (_purchasedLevels.isNotEmpty &&
          !_purchasedLevels.contains(product.level)) { return false; }
      if (_purchasedPushFilter == PurchasedPushFilter.pushing &&
          !lp.pushEnabled) { return false; }
      if (_purchasedPushFilter == PurchasedPushFilter.off &&
          lp.pushEnabled) { return false; }
      final q = _purchasedSearchQuery.trim();
      if (q.isNotEmpty) {
        final t = product.title.toLowerCase();
        final tzh = product.titleZh?.toLowerCase() ?? '';
        if (!t.contains(q.toLowerCase()) && !tzh.contains(q.toLowerCase())) return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) =>
        (b as UserLibraryProduct).purchasedAt.compareTo((a as UserLibraryProduct).purchasedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPurchasedFilterBar(visibleLib, productsMap),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_list_off,
                          size: 48,
                          color: tokens.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        uiString(lang, 'no_purchased_match_filters'),
                        style: TextStyle(
                            color: tokens.textPrimary, fontSize: 16),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        uiString(lang, 'try_change_filters'),
                        style: TextStyle(
                            color: tokens.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (ctx, i) {
                    final lp = filtered[i] as UserLibraryProduct;
        final product = productsMap[lp.productId]!;
        final tokens = ctx.tokens;
        final entry = nextEntryFor(lp.productId);

        // 獲取該產品的內容總數
        final contentAsync = ref.watch(contentByProductProvider(lp.productId));
        final totalItems = contentAsync.maybeWhen(
          data: (items) => items.length,
          orElse: () => null,
        );

        return LibraryRichCard(
          lang: lang,
          title: product.displayTitle(lang),
          coverImageUrl: null,
          totalItems: totalItems,
          level: product.level.isEmpty ? null : product.level,
          nextPushText: lp.pushEnabled
              ? (entry == null
                  ? uiString(lang, 'no_schedule_next_3_days')
                  : uiString(lang, 'next_push_time').replaceFirst('{time}', fmtNextTime(entry.when)))
              : uiString(lang, 'notifications_off'),
          latestTitle: entry == null ? uiString(lang, 'next_not_scheduled') : latestTitleText(entry),
          headerTrailing: PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz, color: tokens.textSecondary),
            onSelected: (v) async {
              final repo = ref.read(libraryRepoProvider);
              final uid2 = ref.read(uidProvider);
              if (v == 'fav') {
                await repo.setProductFavorite(
                    uid2, lp.productId, !lp.isFavorite);
              } else if (v == 'push') {
                // ignore: use_build_context_synchronously
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      PushProductConfigPage(productId: lp.productId),
                ));
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'fav',
                child: Row(
                  children: [
                    Icon(lp.isFavorite ? Icons.star : Icons.star_border),
                    const SizedBox(width: AppSpacing.xs),
                    Text(lp.isFavorite
                        ? uiString(lang, 'remove_from_favorites')
                        : uiString(lang, 'add_to_favorites')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'push',
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined),
                    const SizedBox(width: AppSpacing.xs),
                    Text(uiString(lang, 'notification_settings_title')),
                  ],
                ),
              ),
            ],
          ),
          onLearnNow: () async {
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context)
                .showSnackBar(
              SnackBar(content: Text(uiString(lang, 'logged_one_session_today'))),
            );
          },
          onMakeUpToday: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(
              SnackBar(content: Text(uiString(lang, 'make_up_today_demo'))),
            );
          },
          onPreview3Days: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(
              SnackBar(content: Text(uiString(lang, 'preview_next_3_days_demo'))),
            );
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PushProductConfigPage(productId: lp.productId),
            ));
          },
          onTap: () async {
            await ref
                .read(libraryRepoProvider)
                .touchLastOpened(ref.read(uidProvider), lp.productId);
            // ignore: use_build_context_synchronously
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProductLibraryPage(
                  productId: lp.productId, isWishlistPreview: false),
            ));
          },
        );
      },
    ),
        ),
      ],
    );
  }

  /// 已購買清單篩選列：推播狀態、主題、等級、關鍵字；樣式使用 context.tokens
  Widget _buildPurchasedFilterBar(
    List<dynamic> visibleLib,
    Map<String, Product> productsMap,
  ) {
    final tokens = context.tokens;
    final lang = ref.watch(appLanguageProvider);
    final topicIds = <String>{};
    final levels = <String>{};
    for (final e in visibleLib) {
      final lp = e as UserLibraryProduct;
      final product = productsMap[lp.productId];
      if (product != null) {
        topicIds.add(product.topicId);
        levels.add(product.level);
      }
    }
    final topicList = topicIds.toList()..sort();
    final levelList = levels.toList()..sort();

    final hasActiveFilter = _purchasedTopicIds.isNotEmpty ||
        _purchasedLevels.isNotEmpty ||
        _purchasedPushFilter != PurchasedPushFilter.all ||
        _purchasedSearchQuery.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      color: tokens.bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 推播狀態：三選一
          Row(
            children: [
              _purchasedPushChip(
                tokens,
                PurchasedPushFilter.all,
                uiString(lang, 'all'),
              ),
              const SizedBox(width: 8),
              _purchasedPushChip(
                tokens,
                PurchasedPushFilter.pushing,
                uiString(lang, 'notifications_on'),
              ),
              const SizedBox(width: 8),
              _purchasedPushChip(
                tokens,
                PurchasedPushFilter.off,
                uiString(lang, 'push_off'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // 主題、等級 Chip 多選（橫向捲動）
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  uiString(lang, 'topic_label'),
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                ...topicList.map((tid) {
                  final selected = _purchasedTopicIds.contains(tid);
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: FilterChip(
                      label: Text(tid),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          if (_purchasedTopicIds.contains(tid)) {
                            _purchasedTopicIds.remove(tid);
                          } else {
                            _purchasedTopicIds.add(tid);
                          }
                        });
                      },
                      selectedColor: tokens.primary.withValues(alpha: 0.2),
                      checkmarkColor: tokens.primary,
                      side: BorderSide(
                        color: selected
                            ? tokens.primary
                            : tokens.cardBorder,
                      ),
                    ),
                  );
                }),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  uiString(lang, 'level_label'),
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                ...levelList.map((lv) {
                  final selected = _purchasedLevels.contains(lv);
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: FilterChip(
                      label: Text(lv),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          if (_purchasedLevels.contains(lv)) {
                            _purchasedLevels.remove(lv);
                          } else {
                            _purchasedLevels.add(lv);
                          }
                        });
                      },
                      selectedColor: tokens.primary.withValues(alpha: 0.2),
                      checkmarkColor: tokens.primary,
                      side: BorderSide(
                        color: selected
                            ? tokens.primary
                            : tokens.cardBorder,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // 關鍵字
          TextField(
            decoration: InputDecoration(
              hintText: uiString(lang, 'search_product_title'),
              hintStyle: TextStyle(color: tokens.textSecondary),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: tokens.cardBorder),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
            ),
            style: TextStyle(color: tokens.textPrimary),
            onChanged: (v) => setState(() => _purchasedSearchQuery = v),
          ),
          if (hasActiveFilter) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _purchasedTopicIds.clear();
                  _purchasedLevels.clear();
                  _purchasedPushFilter = PurchasedPushFilter.all;
                  _purchasedSearchQuery = '';
                });
              },
              child: Text(
                uiString(lang, 'clear_filters_btn'),
                style: TextStyle(color: tokens.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _purchasedPushChip(
    AppTokens tokens,
    PurchasedPushFilter value,
    String label,
  ) {
    final selected = _purchasedPushFilter == value;
    return GestureDetector(
      onTap: () =>
          setState(() => _purchasedPushFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected
              ? tokens.primary.withValues(alpha: 0.2)
              : tokens.chipBg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: selected ? tokens.primary : tokens.cardBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? tokens.primary : tokens.textPrimary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildWishlistTab(
    BuildContext context,
    List<WishlistItem> wishItems,
    Map<String, Product> productsMap,
    List<UserLibraryProduct> visibleLib,
    AppLanguage lang,
  ) {
    final tokens = context.tokens;
    
    // ✅ 获取已购买的产品ID集合
    final purchasedProductIds = visibleLib
        .map((lp) => lp.productId)
        .toSet();
    
    // ✅ 过滤：只显示未购买的产品
    final visibleWish = <WishlistItem>[
      ...wishItems.where((e) => 
        productsMap.containsKey(e.productId) && 
        !purchasedProductIds.contains(e.productId) // ✅ 排除已购买
      )
    ]..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    if (visibleWish.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border,
                size: 64, color: tokens.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              uiString(lang, 'wishlist_empty'),
              style: TextStyle(
                  color: tokens.textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              uiString(lang, 'wishlist_hint'),
              style: TextStyle(
                  color: tokens.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: visibleWish.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (_, i) {
        final w = visibleWish[i];
        final p = productsMap[w.productId]!;
        final title = p.displayTitle(lang);

        Widget chip(String label) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: tokens.chipBg,
              border: Border.all(
                  color: tokens.cardBorder),
            ),
            child: Text(label,
                style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          );
        }

        return BubbleCard(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProductLibraryPage(
                productId: w.productId,
                isWishlistPreview: true, // ✅ 試讀模式
              ),
            ));
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline, size: 26),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                        IconButton(
                          tooltip: uiString(lang, 'favorite'),
                          icon: Icon(w.isFavorite
                              ? Icons.star
                              : Icons.star_border),
                          onPressed: () => ref
                              .read(localWishlistNotifierProvider)
                              .toggleFavorite(w.productId),
                        ),
                        IconButton(
                          tooltip: uiString(lang, 'remove_from_wishlist'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => ref
                              .read(localWishlistNotifierProvider)
                              .remove(w.productId),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: 8,
                      children: [
                        chip(uiString(lang, 'not_purchased')),
                        chip(uiString(lang, 'preview_available')),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ProductLibraryPage(
                                productId: w.productId,
                                isWishlistPreview: true,
                              ),
                            ));
                          },
                          child: Text(uiString(lang, 'preview')),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ProductPage(productId: w.productId),
                            ));
                          },
                          child: Text(uiString(lang, 'buy_now')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFavoritesTab(
    BuildContext context,
    List<UserLibraryProduct> visibleLib,
    List<WishlistItem> visibleWish,
    Map<String, Product> productsMap,
    AppLanguage lang,
  ) {
    final tokens = context.tokens;
    final favPids = <String>{};
    for (final lp in visibleLib) {
      if (lp.isFavorite) favPids.add(lp.productId);
    }
    for (final w in visibleWish) {
      if (w.isFavorite) favPids.add(w.productId);
    }

    final favList = favPids.toList();

    if (favList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_border,
                size: 64, color: tokens.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              uiString(lang, 'favorites_empty'),
              style: TextStyle(
                  color: tokens.textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              uiString(lang, 'favorites_hint'),
              style: TextStyle(
                  color: tokens.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: favList.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (ctx, i) {
        final pid = favList[i];
        final title = productsMap[pid]!.displayTitle(lang);
        final lp = visibleLib.where((e) => e.productId == pid).firstOrNull;
        final isPurchased = lp != null;

        return BubbleCard(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProductLibraryPage(
                  productId: pid, isWishlistPreview: !isPurchased),
            ));
          },
          child: Row(
            children: [
              const Icon(Icons.star, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700))),
              Text(isPurchased ? uiString(lang, 'purchased_label') : uiString(lang, 'not_purchased'),
                  style: TextStyle(color: tokens.textSecondary)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryView(BuildContext context, AppLanguage lang) {
    final savedAsync = ref.watch(savedItemsProvider);
    final productsAsync = ref.watch(productsMapProvider);

    return savedAsync.when(
      data: (savedMap) {
        return productsAsync.when(
          data: (productsMap) {
            // ✅ 階段 1：數據重組 - 依產品分組
            // 先批次載入所有 ContentItem
            final allContentIds = savedMap.keys.toList();
            if (allContentIds.isEmpty) {
              return _buildEmptyHistory(context);
            }

            return FutureBuilder<Map<String, ContentItem>>(
              future: _loadAllContentItems(allContentIds),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  final tokens = context.tokens;
                  return Center(
                    child: Text('${uiString(lang, 'load_error')}${snapshot.error}',
                        style: TextStyle(color: tokens.textSecondary)),
                  );
                }

                final contentItemsMap = snapshot.data ?? {};
                
                // 依產品分組，每個產品內再分已學習/待學習
                final groupedByProduct = <String, Map<String, List<String>>>{};

                for (final entry in savedMap.entries) {
                  final contentId = entry.key;
                  final contentItem = contentItemsMap[contentId];
                  if (contentItem == null) continue;

                  final productId = contentItem.productId;
                  groupedByProduct.putIfAbsent(
                    productId,
                    () => {'toLearn': <String>[], 'learned': <String>[]},
                  );

                  if (entry.value.learned) {
                    groupedByProduct[productId]!['learned']!.add(contentId);
                  } else {
                    groupedByProduct[productId]!['toLearn']!.add(contentId);
                  }
                }

                // 排序：依產品名稱（依當前語言顯示標題排序）
                final sortedProducts = groupedByProduct.keys.toList()
                  ..sort((a, b) {
                    final titleA = productsMap[a]?.displayTitle(lang) ?? '';
                    final titleB = productsMap[b]?.displayTitle(lang) ?? '';
                    return titleA.compareTo(titleB);
                  });

                // 應用產品篩選
                final filteredProducts = sortedProducts.where((productId) {
                  return _matchesFilter(productId);
                }).toList();

                return _buildHistoryContentGrouped(
                  context,
                  filteredProducts,
                  groupedByProduct,
                  contentItemsMap,
                  productsMap,
                  _selectedHistoryTab == 0, // showToLearn: true = 待學習, false = 已學習
                  lang,
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('${uiString(lang, 'products_error')}$e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('${uiString(lang, 'saved_items_error')}$e')),
    );
  }

  // 批次載入所有 ContentItem
  Future<Map<String, ContentItem>> _loadAllContentItems(
      List<String> contentIds) async {
    final futures = contentIds.map((id) async {
      try {
        final item = await ref.read(contentItemProvider(id).future);
        return MapEntry(id, item);
      } catch (e) {
        if (kDebugMode) debugPrint('Failed to load ContentItem $id: $e');
        return null;
      }
    });

    final results = await Future.wait(futures);
    return {
      for (final entry in results)
        if (entry != null) entry.key: entry.value
    };
  }

  Widget _buildEmptyHistory(BuildContext context) {
    final tokens = context.tokens;
    final lang = ref.watch(appLanguageProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_edu,
              size: 64, color: tokens.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            uiString(lang, 'history_empty'),
            style: TextStyle(
                color: tokens.textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            uiString(lang, 'history_empty_hint'),
            style: TextStyle(
                color: tokens.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ✅ 階段 2-3：按產品分組顯示 + 性能優化（ListView.builder）
  Widget _buildHistoryContentGrouped(
    BuildContext context,
    List<String> sortedProducts,
    Map<String, Map<String, List<String>>> groupedByProduct,
    Map<String, ContentItem> contentItemsMap,
    Map<String, Product> productsMap,
    bool showToLearn,
    AppLanguage lang,
  ) {
    final tokens = context.tokens;
    // 建立扁平化列表：用於 ListView.builder
    final flatItems = <_HistoryListItem>[];
    
    if (showToLearn) {
      // 待學習區塊
      final toLearnProducts = sortedProducts
          .where((pid) => groupedByProduct[pid]!['toLearn']!.isNotEmpty)
          .toList();
      for (final productId in toLearnProducts) {
        final toLearnIds = groupedByProduct[productId]!['toLearn']!;
        final learnedIds = groupedByProduct[productId]!['learned']!;
        
        if (toLearnIds.isNotEmpty || learnedIds.isNotEmpty) {
          flatItems.add(_HistoryListItem.productHeader(
            productId,
            toLearnIds.length,
            learnedIds.length,
          ));
        }
      }
    } else {
      // 已學習區塊
      final learnedProducts = sortedProducts
          .where((pid) => groupedByProduct[pid]!['learned']!.isNotEmpty)
          .toList();
      for (final productId in learnedProducts) {
        final toLearnIds = groupedByProduct[productId]!['toLearn']!;
        final learnedIds = groupedByProduct[productId]!['learned']!;
        
        if (toLearnIds.isNotEmpty || learnedIds.isNotEmpty) {
          flatItems.add(_HistoryListItem.productHeader(
            productId,
            toLearnIds.length,
            learnedIds.length,
          ));
        }
      }
    }

    // 使用 ListView.builder 優化性能
    return Column(
      children: [
        // ✅ 階段 4：搜尋/篩選 UI
        if (currentView == LibraryView.history) _buildSearchAndFilterBar(),
        Expanded(
          child: flatItems.isEmpty
              ? Center(
                  child: Text(
                    _selectedProductIds.isNotEmpty
                        ? uiString(lang, 'history_no_match_filters')
                            : showToLearn
                            ? uiString(lang, 'no_pending_items')
                            : uiString(lang, 'no_completed_items'),
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: flatItems.length,
                  itemBuilder: (context, index) {
        final item = flatItems[index];
        switch (item.type) {
          case _HistoryItemType.productHeader:
            return _buildProductGroup(
              context,
              item.productId!,
              item.toLearnCount!,
              item.learnedCount!,
              groupedByProduct[item.productId!]!,
              contentItemsMap,
              productsMap,
              showToLearn,
              lang,
            );
          case _HistoryItemType.content:
          case _HistoryItemType.sectionHeader:
          case _HistoryItemType.spacer:
            return const SizedBox.shrink(); // 不再使用，但保留以兼容舊代碼
        }
                  },
                ),
        ),
      ],
    );
  }

  // Tab Chip 組件
  Widget _buildTabChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final tokens = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : tokens.cardBg.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: isSelected ? color : tokens.cardBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? color : tokens.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 階段 4：搜尋/篩選工具列
  Widget _buildSearchAndFilterBar() {
    final lang = ref.watch(appLanguageProvider);
    final savedAsync = ref.watch(savedItemsProvider);
    final productsAsync = ref.watch(productsMapProvider);

    return productsAsync.when(
      data: (productsMap) {
        return savedAsync.when(
          data: (savedMap) {
            final tokens = context.tokens;
            return Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              color: tokens.bg,
              child: Column(
                children: [
                  // Tab 切換器
                  Row(
                    children: [
                      _buildTabChip(
                        context,
                        label: uiString(lang, 'pending'),
                        icon: Icons.schedule,
                        color: tokens.primary,
                        isSelected: _selectedHistoryTab == 0,
                        onTap: () => setState(() => _selectedHistoryTab = 0),
                      ),
                      const SizedBox(width: 8),
                      _buildTabChip(
                        context,
                        label: uiString(lang, 'done'),
                        icon: Icons.check_circle,
                        color: tokens.primary,
                        isSelected: _selectedHistoryTab == 1,
                        onTap: () => setState(() => _selectedHistoryTab = 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 產品篩選 Chip（簡化版：顯示所有產品）
                  // 注意：完整實作需要載入所有 ContentItem 才能知道有哪些產品
                  // 這裡先顯示一個提示
                  if (_selectedProductIds.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: [
                        ..._selectedProductIds.map((productId) {
                          final product = productsMap[productId];
                          return Chip(
                            label: Text(product?.displayTitle(lang) ?? productId),
                            onDeleted: () {
                              setState(() {
                                _selectedProductIds.remove(productId);
                              });
                            },
                          );
                        }),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedProductIds.clear();
                            });
                          },
                          child: Text(uiString(lang, 'clear_filters_btn')),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ✅ 階段 2：產品分組卡片（ExpansionTile）
  Widget _buildProductGroup(
    BuildContext context,
    String productId,
    int toLearnCount,
    int learnedCount,
    Map<String, List<String>> group,
    Map<String, ContentItem> contentItemsMap,
    Map<String, Product> productsMap,
    bool showToLearn,
    AppLanguage lang,
  ) {
    final tokens = context.tokens;
      final product = productsMap[productId];
      final productTitle = product?.displayTitle(lang) ?? uiString(lang, 'unknown_product');
    
    // 根據 showToLearn 過濾內容
    final filteredToLearn = showToLearn ? group['toLearn']! : <String>[];
    final filteredLearned = !showToLearn ? group['learned']! : <String>[];
    
    // 排序內容：依 seq
    filteredToLearn.sort((a, b) {
      final seqA = contentItemsMap[a]?.seq ?? 0;
      final seqB = contentItemsMap[b]?.seq ?? 0;
      return seqA.compareTo(seqB);
    });
    filteredLearned.sort((a, b) {
      final seqA = contentItemsMap[a]?.seq ?? 0;
      final seqB = contentItemsMap[b]?.seq ?? 0;
      return seqA.compareTo(seqB);
    });
    
    final displayCount = showToLearn ? filteredToLearn.length : filteredLearned.length;
    final subtitleLabel = showToLearn ? uiString(lang, 'pending') : uiString(lang, 'done');
    final subtitle = '$subtitleLabel: $displayCount';
    final itemsText = uiString(lang, 'items_only').replaceFirst('{n}', '$displayCount');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BubbleCard(
        child: ExpansionTile(
          title: Text(
            productTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            '$itemsText ($subtitle)',
            style: TextStyle(
              fontSize: 12,
              color: tokens.textSecondary,
            ),
          ),
          children: [
            // 根據 showToLearn 顯示對應的內容
            if (showToLearn && filteredToLearn.isNotEmpty)
              ...filteredToLearn.map((contentId) {
                final contentItem = contentItemsMap[contentId];
                if (contentItem == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: _buildHistoryCard(
                    context,
                    contentId,
                    false,
                    productsMap,
                    contentItem,
                    lang,
                  ),
                );
              })
            else if (!showToLearn && filteredLearned.isNotEmpty)
              ...filteredLearned.map((contentId) {
                final contentItem = contentItemsMap[contentId];
                if (contentItem == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: _buildHistoryCard(
                    context,
                    contentId,
                    true,
                    productsMap,
                    contentItem,
                    lang,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    String contentItemId,
    bool isLearned,
    Map<String, Product> productsMap,
    ContentItem? contentItem, // 可選，如果已載入則直接使用
    AppLanguage lang,
  ) {
    // 如果已提供 contentItem，直接使用；否則從 provider 載入
    if (contentItem != null) {
      return _buildHistoryCardContent(
        context,
        contentItemId,
        isLearned,
        productsMap,
        contentItem,
        lang,
      );
    }

    final contentAsync = ref.watch(contentItemProvider(contentItemId));

    return contentAsync.when(
      data: (item) => _buildHistoryCardContent(
        context,
        contentItemId,
        isLearned,
        productsMap,
        item,
        lang,
      ),
      loading: () => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.xs),
        child: BubbleCard(
          child: SizedBox(
            height: 64,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: BubbleCard(
          child: Text('${uiString(lang, 'load_error')}$e',
              style: TextStyle(color: context.tokens.textSecondary)),
        ),
      ),
    );
  }

  Widget _buildHistoryCardContent(
    BuildContext context,
    String contentItemId,
    bool isLearned,
    Map<String, Product> productsMap,
    ContentItem contentItem,
    AppLanguage lang,
  ) {
    final product = productsMap[contentItem.productId];
    final productTitle = product?.displayTitle(lang) ?? uiString(lang, 'unknown_product');
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Container(
        // ✅ 步驟 1：背景色區分狀態
        decoration: BoxDecoration(
          color: isLearned
              ? tokens.primary.withValues(alpha: 0.1) // 已學習：主題色背景
              : tokens.cardBorder.withValues(alpha: 0.3), // 待學習：淺色背景
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            BubbleCard(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DetailPage(contentItemId: contentItemId),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 產品名稱（上方，更大更突出）
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 16,
                        color: tokens.textPrimary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          productTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: tokens.textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 內容標題（下方，較小，使用 textSecondary 確保在淺色/深色主題都可見）
                  // ✅ 步驟 2：內容標題前加圖示
                  Row(
                    children: [
                      Icon(
                        isLearned
                            ? Icons.check_circle
                            : Icons.schedule, // 待學習=時鐘圖示，已學習=勾選圖示
                        size: 16,
                        color: isLearned
                            ? tokens.primary
                            : tokens.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          '#${contentItem.seq} · ${contentItem.displayAnchorGroup(lang)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ✅ 步驟 3：按鈕改為 Chip，放在內容標題下方
                  Align(
                    alignment: Alignment.centerRight,
                    child: ActionChip(
                      avatar: Icon(
                        isLearned ? Icons.undo : Icons.check_circle,
                        size: 16,
                        color: isLearned
                            ? tokens.textSecondary
                            : tokens.primary,
                      ),
                      label: Text(
                        isLearned ? uiString(lang, 'mark_pending') : uiString(lang, 'mark_done'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isLearned
                              ? tokens.textSecondary
                              : tokens.primary,
                        ),
                      ),
                      onPressed: () async {
                        final uid = ref.read(uidProvider);
                        final repo = ref.read(libraryRepoProvider);
                        await repo.setSavedItem(
                          uid,
                          contentItemId,
                          {'learned': !isLearned},
                        );
                        // 以「標記學會」為準：從待學改為已學時更新 streak
                        if (!isLearned) {
                          await UserLearningStore().markLearnedTodayAndGlobal(contentItem.productId);
                        }
                        ref.invalidate(savedItemsProvider);
                        _triggerReschedule();
                      },
                      backgroundColor: isLearned
                          ? null // 已學習：Outlined 樣式
                          : tokens.primary.withValues(alpha: 0.2), // 待學習：主題色背景
                      side: isLearned
                          ? BorderSide(color: tokens.textSecondary)
                          : null,
                    ),
                  ),
                  if (contentItem.displayContent(lang).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Builder(builder: (_) {
                      final contentText = contentItem.displayContent(lang);
                      return Text(
                        contentText.length > 100
                            ? '${contentText.substring(0, 100)}...'
                            : contentText,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      );
                    }),
                  ],
                ],
              ),
            ),
            // ✅ 步驟 1：Badge（右上角）
            Positioned(
              top: 8,
              right: 8,
              child: Tooltip(
                message: isLearned
                    ? uiString(lang, 'badge_done_tooltip')
                    : uiString(lang, 'badge_pending_tooltip'),
                waitDuration: const Duration(milliseconds: 500),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: isLearned
                        ? tokens.primary.withValues(alpha: 0.2) // 已學習：主題色
                        : tokens.cardBorder.withValues(alpha: 0.4), // 待學習：淺色
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                      color: isLearned ? tokens.primary : tokens.textSecondary,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLearned ? Icons.check_circle : Icons.schedule,
                        size: 12,
                        color: isLearned ? tokens.primary : tokens.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        isLearned ? uiString(lang, 'done') : uiString(lang, 'pending'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isLearned ? tokens.primary : tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool _matchesFilter(String productId) {
    if (_selectedProductIds.isEmpty) return true;
    return _selectedProductIds.contains(productId);
  }

  // ✅ 階段 10：觸發重排（帶防抖，500ms 內僅重排一次）
  void _triggerReschedule() {
    final now = DateTime.now();
    if (_lastRescheduleTime != null &&
        now.difference(_lastRescheduleTime!).inMilliseconds < 500) {
      return; // 防抖：500ms 內不重複觸發
    }
    _lastRescheduleTime = now;
    
    // 異步觸發重排，不阻塞 UI
    Future.microtask(() async {
      try {
        await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
      } catch (e) {
        if (kDebugMode) debugPrint('Reschedule failed: $e');
      }
    });
  }

  Widget _buildFavoriteSentencesTab(BuildContext context) {
    // 檢查是否登入
    String? uid;
    try {
      uid = ref.read(uidProvider);
    } catch (_) {
      final lang = ref.watch(appLanguageProvider);
      return Center(child: Text(uiString(lang, 'sign_in_to_use_feature')));
    }

    final productsAsync = ref.watch(productsMapProvider);

    return productsAsync.when(
      data: (productsMap) {
        return FutureBuilder<List<FavoriteSentence>>(
          future: FavoriteSentencesStore.loadAll(uid!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              final tokens = context.tokens;
              final lang = ref.watch(appLanguageProvider);
              return Center(
                child: Text('${uiString(lang, 'load_error')}${snapshot.error}',
                    style: TextStyle(color: tokens.textSecondary)),
              );
            }

            final sentences = snapshot.data ?? [];

            if (sentences.isEmpty) {
              final tokens = context.tokens;
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.format_quote,
                        size: 64, color: tokens.textSecondary.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      uiString(ref.watch(appLanguageProvider), 'favorite_sentences_hint'),
                      style: TextStyle(
                          color: tokens.textSecondary.withValues(alpha: 0.6),
                          fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.sm),
              itemCount: sentences.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final sentence = sentences[index];
                final tokens = context.tokens;

                final lang = ref.watch(appLanguageProvider);
                // 格式化收藏日期
                String formatDate(DateTime date, AppLanguage l) {
                  final now = DateTime.now();
                  final diff = now.difference(date);
                  if (diff.inDays == 0) {
                    return uiString(l, 'today_label');
                  } else if (diff.inDays == 1) {
                    return uiString(l, 'yesterday_label');
                  } else if (diff.inDays < 7) {
                    return uiString(l, 'days_ago').replaceFirst('{n}', '${diff.inDays}');
                  } else {
                    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
                  }
                }

                return BubbleCard(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            DetailPage(contentItemId: sentence.contentItemId),
                      ),
                    );
                  },
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 產品名稱（標題）
                          Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 16,
                                color: tokens.textPrimary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  sentence.productName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: tokens.textPrimary,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // anchor group（副標題）
                          Row(
                            children: [
                              Icon(
                                Icons.label_outline,
                                size: 14,
                                color: tokens.textSecondary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  sentence.anchorGroup,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          // anchor（小字）
                          Text(
                            sentence.anchor,
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.textSecondary.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          // content（「今日一句」內容，主要顯示）
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: tokens.cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: tokens.cardBorder,
                              ),
                            ),
                            child: Text(
                              sentence.content,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 收藏日期（右下角）
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              formatDate(sentence.favoritedAt, lang),
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.textSecondary.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // 刪除按鈕（右上角）
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: tokens.textSecondary.withValues(alpha: 0.6),
                          onPressed: () async {
                            if (uid == null) return;
                            await FavoriteSentencesStore.remove(
                                uid, sentence.contentItemId);
                            // 刷新列表
                            setState(() {});
                          },
                          tooltip: uiString(lang, 'remove_from_saved'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('${uiString(ref.watch(appLanguageProvider), 'products_error')}$e')),
    );
  }
}

// ✅ 階段 1-3：學習歷史列表項目的數據結構
enum _HistoryItemType { sectionHeader, productHeader, content, spacer }

class _HistoryListItem {
  final _HistoryItemType type;
  final String? productId;
  final int? toLearnCount;
  final int? learnedCount;

  _HistoryListItem._({
    required this.type,
    this.productId,
    this.toLearnCount,
    this.learnedCount,
  });

  factory _HistoryListItem.productHeader(
    String productId,
    int toLearnCount,
    int learnedCount,
  ) =>
      _HistoryListItem._(
        type: _HistoryItemType.productHeader,
        productId: productId,
        toLearnCount: toLearnCount,
        learnedCount: learnedCount,
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
