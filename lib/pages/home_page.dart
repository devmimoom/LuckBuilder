import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/v2_providers.dart';
import '../providers/home_sections_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/product_rail.dart';
import '../theme/app_tokens.dart';
import '../data/models.dart';
import '../widgets/rich_sections/sections/home_for_you_section.dart';
import '../widgets/rich_sections/user_learning_store.dart';
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
                : SizedBox(
                    height: 220,
                    child: PageView.builder(
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
            loading: () => const SizedBox(
                height: 220, child: Center(child: CircularProgressIndicator())),
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
            loading: () => const SizedBox(
                height: 212, child: Center(child: CircularProgressIndicator())),
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
            loading: () => const SizedBox(
                height: 212, child: Center(child: CircularProgressIndicator())),
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
            loading: () => const SizedBox(
                height: 180, child: Center(child: CircularProgressIndicator())),
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
            loading: () => const SizedBox(
                height: 212, child: Center(child: CircularProgressIndicator())),
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

class _BannerCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const _BannerCard({required this.product, required this.onTap});

  static const double _bannerHeight = 220.0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: SizedBox(
          height: _bannerHeight,
          width: double.infinity,
          child: product.coverImageUrl != null &&
                  product.coverImageUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Image.network(
                    product.coverImageUrl!,
                    width: double.infinity,
                    height: _bannerHeight,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: _bannerHeight,
                      color: tokens.chipBg,
                      child: Icon(Icons.image_not_supported,
                          color: tokens.textSecondary),
                    ),
                  ),
                )
              : Container(
                  height: _bannerHeight,
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

