import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/v2_providers.dart';
import '../providers/home_sections_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/product_rail.dart';
import '../theme/app_tokens.dart';
import '../theme/layout_constants.dart';
import '../data/models.dart';
import '../widgets/rich_sections/sections/home_for_you_section.dart';
import '../widgets/rich_sections/user_learning_store.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'product_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(bannerProductsProvider);
    final weekly = ref.watch(featuredProductsProvider('weekly_pick'));
    final hot = ref.watch(featuredProductsProvider('hot_all'));
    final newArrivals = ref.watch(HomeSectionsProvider.newArrivalsProvider);
    final comingSoon = ref.watch(HomeSectionsProvider.comingSoonProvider);
    final tokens = context.tokens;

    // 動態計算 loading 佔位高度（與 ProductRail 計算一致）
    final screenWidth = MediaQuery.of(context).size.width;
    final lgCardW = (screenWidth * 0.45).clamp(180.0, kMaxCardWidth);
    final smCardW = (screenWidth * 0.55).clamp(180.0, kMaxSmallCardWidth);
    final lgLoadingH = lgCardW / kCoverAspectRatio + 100; // large textArea
    final smLoadingH = smCardW / kCoverAspectRatio + 78;  // small textArea

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner 1~3（首頁最上方）
          banners.when(
            data: (ps) => ps.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          'No banner data. Check Firestore featured_lists/home_banners.',
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                  )
                : AspectRatio(
                    aspectRatio: kBannerAspectRatio,
                    child: _BannerCarousel(products: ps),
                  ),
            loading: () => const AspectRatio(
                aspectRatio: kBannerAspectRatio,
                child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Banner error:',
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
          const SizedBox(height: 18),

          const _Section(title: 'Top Picks'),
          hot.when(
            data: (ps) => ps.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No data for Top Picks.',
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                  )
                : ProductRail(
                    products: ps,
                    size: ProductRailSize.large,
                    ctaText: 'View',
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
                    Text('Top Picks error:',
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
          const SizedBox(height: 18),

          // ✅ 新上架
          const _Section(title: 'New Arrivals'),
          newArrivals.when(
            data: (ps) => ps.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          'No new arrivals.',
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                  )
                : ProductRail(
                    products: ps,
                    size: ProductRailSize.large,
                    ctaText: 'View',
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
                    Text('New Arrivals error:',
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
          const SizedBox(height: 18),

          // ✅ 即將上架
          const _Section(title: 'Coming Soon'),
          comingSoon.when(
            data: (ps) => ps.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          'No coming soon items.',
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                  )
                : ProductRail(
                    products: ps,
                    size: ProductRailSize.small,
                    badgeText: 'SOON',
                    dim: true,
                    showReleaseDate: true,
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
                    Text('Coming Soon error:',
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
          const SizedBox(height: 18),

          // 為你推薦
          const HomeForYouSection(),
          const SizedBox(height: 18),

          const _Section(title: 'Featured'),
          weekly.when(
            data: (ps) => ps.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No featured items.',
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                  )
                : ProductRail(
                    products: ps,
                    size: ProductRailSize.large,
                    ctaText: 'View',
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
                    Text('Featured error:',
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
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text('│ $title',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary)),
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  final List<Product> products;

  const _BannerCarousel({required this.products});

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
    final ps = widget.products;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: ps.length,
            itemBuilder: (_, i) => _BannerCard(
              product: ps[i],
              onTap: () {
                unawaited(
                    UserLearningStore().markGlobalLearnedToday());
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProductPage(productId: ps[i].id),
                ));
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(ps.length, (i) {
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
  final Product product;
  final VoidCallback onTap;
  const _BannerCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: SizedBox.expand(
          child: product.coverImageUrl != null &&
                  product.coverImageUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: CachedNetworkImage(
                    imageUrl: product.coverImageUrl!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    placeholder: (context, url) => Container(
                      color: tokens.chipBg,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: tokens.chipBg,
                      child: Icon(Icons.image_not_supported,
                          color: tokens.textSecondary),
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: tokens.chipBg,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Icon(Icons.auto_awesome, color: tokens.textSecondary),
                ),
        ),
      ),
    );
  }
}

