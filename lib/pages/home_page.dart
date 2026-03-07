import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/v2_providers.dart';
import '../providers/home_sections_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/product_rail.dart';
import '../theme/app_tokens.dart';
import '../theme/layout_constants.dart';
import '../data/models.dart';
import '../widgets/rich_sections/sections/home_for_you_section.dart';
import '../localization/app_language.dart';
import '../localization/app_language_provider.dart';
import '../localization/app_strings.dart';
import '../services/wishlist_request_service.dart';
import 'product_page.dart';
import 'product_list_page.dart';
import 'search_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(bannerItemsProvider);
    final weekly = ref.watch(featuredProductsProvider('weekly_pick'));
    final hot = ref.watch(featuredProductsProvider('hot_all'));
    final newArrivals = ref.watch(HomeSectionsProvider.newArrivalsProvider);
    final comingSoon = ref.watch(HomeSectionsProvider.comingSoonProvider);
    final lang = ref.watch(appLanguageProvider);
    final tokens = context.tokens;

    final screenWidth = MediaQuery.of(context).size.width;
    final lgCardW = (screenWidth * 0.45).clamp(180.0, kMaxCardWidth);
    final smCardW = (screenWidth * 0.55).clamp(180.0, kMaxSmallCardWidth);
    final lgLoadingH = lgCardW / kCoverAspectRatio + 100;
    final smLoadingH = smCardW / kCoverAspectRatio + 78;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _GreetingHeader(
            lang: lang,
            onSearch: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      leading: const BackButton(),
                      title: Text(uiString(lang, 'search')),
                    ),
                    body: const SearchPage(),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // ── Banner Carousel ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(kPageHorizontalPadding, 0, kPageHorizontalPadding, 0),
            child: banners.when(
              data: (items) => items.isEmpty
                  ? AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                            uiString(lang, 'no_banner_data'),
                            style: TextStyle(color: tokens.textSecondary)),
                      ),
                    )
                  : AspectRatio(
                      aspectRatio: kHomeHeroAspectRatio,
                      child: _BannerCarousel(items: items, lang: lang),
                    ),
              loading: () => const AspectRatio(
                  aspectRatio: kHomeHeroAspectRatio,
                  child: Center(child: CircularProgressIndicator())),
              error: (err, stack) => AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(uiString(lang, 'banner_error'),
                          style: TextStyle(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('$err',
                          style: TextStyle(
                              color: tokens.textSecondary, fontSize: 12),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ── Top Picks ─────────────────────────────────
          _Section(title: uiString(lang, 'top_picks'), emoji: '🔥'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kPageHorizontalPadding),
            child: hot.when(
            data: (ps) => ps.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(uiString(lang, 'no_data_top_picks'),
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                  )
                : ProductRail(
                    products: ps,
                    size: ProductRailSize.large,
                    ctaText: uiString(lang, 'view'),
                    lang: lang,
                  ),
            loading: () => SizedBox(
                height: lgLoadingH,
                child: const Center(child: CircularProgressIndicator())),
            error: (err, stack) => AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(uiString(lang, 'top_picks_error'),
                        style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '$err',
                      style:
                          TextStyle(color: tokens.textSecondary, fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
          const SizedBox(height: 18),

          // ── New Arrivals ──────────────────────────────
          _Section(title: uiString(lang, 'new_arrivals'), emoji: '✨'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kPageHorizontalPadding),
            child: newArrivals.when(
            data: (ps) => ps.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          uiString(lang, 'no_new_arrivals'),
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                  )
                : ProductRail(
                    products: ps,
                    size: ProductRailSize.large,
                    ctaText: uiString(lang, 'view'),
                    lang: lang,
                  ),
            loading: () => SizedBox(
                height: lgLoadingH,
                child: const Center(child: CircularProgressIndicator())),
            error: (err, stack) => AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(uiString(lang, 'new_arrivals_error'),
                        style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '$err',
                      style:
                          TextStyle(color: tokens.textSecondary, fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
          const SizedBox(height: 18),

          // ── Coming Soon ───────────────────────────────
          _Section(title: uiString(lang, 'coming_soon'), emoji: '🔮'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kPageHorizontalPadding),
            child: comingSoon.when(
            data: (ps) => ps.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          uiString(lang, 'no_coming_soon'),
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                  )
                : ProductRail(
                    products: ps,
                    size: ProductRailSize.small,
                    badgeText: 'SOON',
                    dim: true,
                    showReleaseDate: true,
                    lang: lang,
                  ),
            loading: () => SizedBox(
                height: smLoadingH,
                child: const Center(child: CircularProgressIndicator())),
            error: (err, stack) => AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(uiString(lang, 'coming_soon_error'),
                        style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '$err',
                      style:
                          TextStyle(color: tokens.textSecondary, fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
          const SizedBox(height: 18),

          // ── For You ───────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: kPageHorizontalPadding),
            child: HomeForYouSection(),
          ),
          const SizedBox(height: 18),

          // ── Featured ──────────────────────────────────
          _Section(title: uiString(lang, 'featured'), emoji: '🌟'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kPageHorizontalPadding),
            child: weekly.when(
            data: (ps) => ps.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(uiString(lang, 'no_featured'),
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                  )
                : ProductRail(
                    products: ps,
                    size: ProductRailSize.large,
                    ctaText: uiString(lang, 'view'),
                    lang: lang,
                  ),
            loading: () => SizedBox(
                height: lgLoadingH,
                child: const Center(child: CircularProgressIndicator())),
            error: (err, stack) => AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(uiString(lang, 'featured_error'),
                        style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '$err',
                      style:
                          TextStyle(color: tokens.textSecondary, fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _Section(title: uiString(lang, 'wishlist_request_title'), emoji: '⭐'),
          const SizedBox(height: 10),
          _WishlistRequestSection(lang: lang),
          const SizedBox(height: 18),
          _HomeLegalLinks(lang: lang),
        ],
      ),
    );
  }
}

Future<void> _launchUrl(BuildContext context, String url, AppLanguage lang) async {
  try {
    final uri = Uri.parse(url);
    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${uiString(lang, 'could_not_open')}$url')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${uiString(lang, 'could_not_open_link')}$e')),
      );
    }
  }
}

class _HomeLegalLinks extends StatelessWidget {
  const _HomeLegalLinks({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    const privacyUrl =
        'https://immediate-beast-f57.notion.site/OnePop-Privacy-Policy-2fb560db78bf80f0a4ccdd9ad7e34e7e?source=copy_link';
    const termsUrl =
        'https://immediate-beast-f57.notion.site/OnePop-Terms-of-Use-2fb560db78bf80ff9f7cd030e0b646d8?source=copy_link';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kPageHorizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: () => _launchUrl(context, termsUrl, lang),
            child: Text(
              uiString(lang, 'terms_of_use_footer'),
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          Text(
            '·',
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 12,
            ),
          ),
          TextButton(
            onPressed: () => _launchUrl(context, privacyUrl, lang),
            child: Text(
              uiString(lang, 'privacy_policy_footer'),
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WishlistRequestSection extends StatefulWidget {
  const _WishlistRequestSection({required this.lang});
  final AppLanguage lang;

  @override
  State<_WishlistRequestSection> createState() => _WishlistRequestSectionState();
}

class _WishlistRequestSectionState extends State<_WishlistRequestSection> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode(skipTraversal: true);
  final FocusNode _descFocusNode = FocusNode(skipTraversal: true);
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _nameFocusNode.dispose();
    _descFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final name = _nameController.text.trim();
    final desc = _descController.text.trim();

    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(uiString(widget.lang, 'wishlist_request_empty_name')),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await WishlistRequestService.submitWishlist(
        productName: name,
        description: desc.isEmpty ? null : desc,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(uiString(widget.lang, 'wishlist_request_success')),
        ),
      );
      _nameController.clear();
      _descController.clear();
    } catch (e) {
      if (!mounted) return;
      final base = uiString(widget.lang, 'wishlist_request_error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$base$e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kPageHorizontalPadding),
      child: AppCard(
        child: Focus(
          skipTraversal: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
            Text(
              uiString(widget.lang, 'wishlist_request_subtitle'),
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              uiString(widget.lang, 'wishlist_request_name_label'),
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              decoration: InputDecoration(
                hintText:
                    uiString(widget.lang, 'wishlist_request_name_hint'),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            Text(
              uiString(widget.lang, 'wishlist_request_desc_label'),
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _descController,
              focusNode: _descFocusNode,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    uiString(widget.lang, 'wishlist_request_desc_hint'),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            tokens.textOnPrimary,
                          ),
                        ),
                      )
                    : Text(
                        uiString(
                            widget.lang, 'wishlist_request_submit'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

// ── ① Greeting Header ──────────────────────────────────────
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.lang, required this.onSearch});
  final AppLanguage lang;
  final VoidCallback onSearch;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return uiString(lang, 'good_morning');
    if (hour < 17) return uiString(lang, 'good_afternoon');
    return uiString(lang, 'good_evening');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPageHorizontalPadding, 16, kPageHorizontalPadding, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                uiString(lang, 'what_are_we_learning_today'),
                style: TextStyle(
                  color: tokens.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: onSearch,
            icon: Icon(Icons.search, color: tokens.primary, size: 26),
            style: IconButton.styleFrom(
              backgroundColor: tokens.primary.withValues(alpha: 0.12),
              padding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ② Section Label: Dark = amber bar + amber text; Light = amber bar + dark text
class _Section extends StatelessWidget {
  final String title;
  final String emoji;

  const _Section({required this.title, this.emoji = ''});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPageHorizontalPadding, 0, kPageHorizontalPadding, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [
                  tokens.primary,
                  tokens.primary.withValues(alpha: 0.4),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (emoji.isNotEmpty) ...[
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: tokens.sectionTitleColor,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  final List<BannerItem> items;
  final AppLanguage lang;

  const _BannerCarousel({required this.items, required this.lang});

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage && mounted) {
        setState(() => _currentPage = page);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final items = widget.items;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: items.length,
            itemBuilder: (_, i) => _BannerCard(
              item: items[i],
              lang: widget.lang,
              onTap: () {
                final b = items[i];
                if (b.products.isEmpty) return; // 理論上不應發生（repository 不建空 BannerItem）
                if (b.products.length == 1) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProductPage(productId: b.products.first.id),
                  ));
                } else {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProductListPage(
                      productIds: b.products.map((p) => p.id).toList(),
                      title: b.titleOverride ?? b.titleZhOverride,
                    ),
                  ));
                }
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(items.length, (i) {
              final isActive = i == _currentPage;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 8 : 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? tokens.primary
                      : tokens.textSecondary.withValues(alpha: 0.4),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  final BannerItem item;
  final AppLanguage lang;
  final VoidCallback onTap;
  const _BannerCard({
    required this.item,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final product = item.leadingProduct;
    final imageUrl = item.imageUrl ?? product?.coverImageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final title = lang == AppLanguage.zhTw
        ? (item.titleZhOverride?.isNotEmpty == true
            ? item.titleZhOverride!
            : (product?.titleZh?.isNotEmpty == true ? product!.titleZh! : product?.title ?? ''))
        : (item.titleOverride?.isNotEmpty == true
            ? item.titleOverride!
            : (product?.titleEn?.isNotEmpty == true ? product!.titleEn! : product?.title ?? ''));
    // 繁中介面不再顯示「精華速讀」副標
    final String? subtitle =
        lang == AppLanguage.zhTw ? null : uiString(lang, 'quick_read');

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox.expand(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 背景圖（優先 itemImageUrl，否則產品封面）
              if (hasImage)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  placeholder: (context, url) => Container(
                    color: tokens.chipBg,
                    child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: tokens.chipBg,
                    child: Icon(Icons.image_not_supported,
                        color: tokens.textSecondary),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(color: tokens.chipBg),
                  child: Icon(Icons.auto_awesome, color: tokens.textSecondary),
                ),
              // 漸層 overlay：底部較深，方便讀標題與按鈕
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      stops: const [0.35, 0.65, 1.0],
                    ),
                  ),
                ),
              ),
              // 標題、副標、Open 按鈕
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Center(
                      child: Material(
                        color: tokens.primary,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            child: Text(
                              uiString(lang, 'open'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

