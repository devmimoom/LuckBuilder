import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/home_page.dart';
import 'pages/explore_page.dart';
import 'pages/me_page.dart';
import 'pages/plus_guide/plus_guide_page.dart';
import 'widgets/app_background.dart';
import 'theme/theme_controller.dart';
import 'theme/app_spacing.dart';
import 'theme/app_tokens.dart';
import 'providers/nav_providers.dart';
import 'providers/analytics_provider.dart';
import 'notifications/notification_bootstrapper.dart';
import 'localization/app_language_provider.dart';
import 'localization/app_strings.dart';

final themeControllerProvider = Provider<ThemeController>((ref) {
  throw UnimplementedError('themeControllerProvider must be overridden');
});

const _stackScreenNames = ['home', 'plus', 'explore', 'me'];

class MainScaffold4Tabs extends ConsumerWidget {
  final ThemeController themeController;
  const MainScaffold4Tabs({super.key, required this.themeController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stackIndex = ref.watch(bottomTabIndexProvider);
    final tokens = context.tokens;
    final lang = ref.watch(appLanguageProvider);
    final homeLabel = uiString(lang, 'home');
    final exploreLabel = uiString(lang, 'explore');
    final meLabel = uiString(lang, 'me');

    return NotificationBootstrapper(
        child: AppBackground(
          child: Scaffold(
          backgroundColor: Colors.transparent,
          body: IndexedStack(
            index: stackIndex,
            children: const [
              HomePage(),
              PlusGuidePage(),
              ExplorePage(),
              MePage(),
            ],
          ),
          bottomNavigationBar: _MainBottomBar(
            currentIndex: stackIndex,
            tokens: tokens,
            homeLabel: homeLabel,
            exploreLabel: exploreLabel,
            meLabel: meLabel,
            onItemSelected: (index) {
              ref.read(bottomTabIndexProvider.notifier).state = index;
              if (index >= 0 && index < _stackScreenNames.length) {
                ref
                    .read(analyticsProvider)
                    .logScreenView(screenName: _stackScreenNames[index]);
              }
            },
          ),
          ),
        ),
      );
  }
}

class _MainBottomBar extends StatelessWidget {
  const _MainBottomBar({
    required this.currentIndex,
    required this.tokens,
    required this.homeLabel,
    required this.exploreLabel,
    required this.meLabel,
    required this.onItemSelected,
  });

  final int currentIndex;
  final AppTokens tokens;
  final String homeLabel;
  final String exploreLabel;
  final String meLabel;
  final ValueChanged<int> onItemSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
      child: SizedBox(
        height: AppSpacing.navItemHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: AppSpacing.xxl,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [tokens.primary, tokens.primaryBright],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.primary.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _NavItemButton(
                        index: 0,
                        currentIndex: currentIndex,
                        iconData: Icons.home_outlined,
                        selectedIconData: Icons.home,
                        label: homeLabel,
                        tokens: tokens,
                        onTap: () => onItemSelected(0),
                      ),
                      const SizedBox(width: AppSpacing.xxl),
                      _NavItemButton(
                        index: 2,
                        currentIndex: currentIndex,
                        iconData: Icons.explore_outlined,
                        selectedIconData: Icons.explore,
                        label: exploreLabel,
                        tokens: tokens,
                        onTap: () => onItemSelected(2),
                      ),
                      _NavItemButton(
                        index: 3,
                        currentIndex: currentIndex,
                        iconData: Icons.person_outline,
                        selectedIconData: Icons.person,
                        label: meLabel,
                        tokens: tokens,
                        onTap: () => onItemSelected(3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: const Alignment(-0.25, 0.0),
                child: _PlusFloatingButton(
                  tokens: tokens,
                  selected: currentIndex == 1,
                  onTap: () => onItemSelected(1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemButton extends StatelessWidget {
  const _NavItemButton({
    required this.index,
    required this.currentIndex,
    required this.iconData,
    required this.selectedIconData,
    required this.label,
    required this.tokens,
    required this.onTap,
  });

  final int index;
  final int currentIndex;
  final IconData iconData;
  final IconData selectedIconData;
  final String label;
  final AppTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = index == currentIndex;
    final Color iconColor = selected
        ? tokens.textOnPrimary
        : tokens.textOnPrimary.withValues(alpha: 0.65);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected
              ? tokens.textOnPrimary.withValues(alpha: 0.12)
              : Colors.transparent,
          border: selected
              ? Border.all(
                  color: tokens.textOnPrimary.withValues(alpha: 0.16),
                  width: 1,
                )
              : null,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(
              selected ? selectedIconData : iconData,
              color: iconColor,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                color: iconColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlusFloatingButton extends StatelessWidget {
  const _PlusFloatingButton({
    required this.tokens,
    required this.selected,
    required this.onTap,
  });

  final AppTokens tokens;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 無圓形外框：僅加號線條。未選中亦用 textOnPrimary 系以在 primary 條上可讀。
    final Color plusColor = selected
        ? tokens.textOnPrimary
        : tokens.textOnPrimary.withValues(alpha: 0.8);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: AppSpacing.xxl,
        height: AppSpacing.xxl,
        decoration: BoxDecoration(
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: tokens.primary.withValues(alpha: 0.5),
              blurRadius: 16,
              spreadRadius: 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '+',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: plusColor,
            height: 1,
          ),
        ),
      ),
    );
  }
}
