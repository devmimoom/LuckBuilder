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
          // ✅ 新上架
          const _Section(title: '新上架'),
          newArrivals.when(
            data: (ps) => ps.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          '新上架: 無資料',
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                  )
                : ProductRail(
                    products: ps,
                    size: ProductRailSize.large,
                    ctaText: '立即查看',
                  ),
            loading: () => const SizedBox(
                height: 232, child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('新上架錯誤:',
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
          const _Section(title: '即將上架'),
          comingSoon.when(
            data: (ps) => ps.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          '即將上架: 無資料',
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
                    Text('即將上架錯誤:',
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

          // Banner 1~3
          banners.when(
            data: (ps) => ps.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          'Banner: 無資料（請檢查 Firestore featured_lists/home_banners）',
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                  )
                : SizedBox(
                    height: 160,
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
                height: 160, child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Banner 錯誤:',
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

          const _Section(title: '本週精選'),
          weekly.when(
            data: (ps) => ps.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('本週精選: 無資料',
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                  )
                : ProductRail(
                    products: ps,
                    size: ProductRailSize.large,
                  ),
            loading: () => const SizedBox(
                height: 210, child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('本週精選錯誤:',
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

          const _Section(title: '熱門爆款'),
          hot.when(
            data: (ps) => ps.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('熱門爆款: 無資料',
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                  )
                : ProductRail(
                    products: ps,
                    size: ProductRailSize.large,
                  ),
            loading: () => const SizedBox(
                height: 210, child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('熱門爆款錯誤:',
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

  static const double _bannerHeight = 160.0;

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

