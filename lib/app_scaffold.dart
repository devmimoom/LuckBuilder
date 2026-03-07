import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/home_page.dart';
import 'pages/explore_page.dart';
import 'pages/me_page.dart';
import 'pages/plus_guide/plus_guide_page.dart';
import 'widgets/app_background.dart';
import 'theme/theme_controller.dart';
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
    final Color? capsuleColor = tokens.navGradient == null
        ? Color.lerp(tokens.navBg, tokens.primary, 0.25)!
        : null;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SizedBox(
        height: 72,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: tokens.navGradient,
                  color: capsuleColor,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      const SizedBox(width: 56),
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
    final Color iconColor =
        selected ? tokens.textPrimary : tokens.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
          border: selected
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
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
              size: 22,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: iconColor,
                fontSize: 11,
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
    return GestureDetector(
      onTap: onTap,
      child: Transform.translate(
        offset: Offset.zero,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? tokens.primary
                : tokens.primary.withValues(alpha: 0.2),
            boxShadow: [
              BoxShadow(
                color: tokens.primary.withValues(alpha: 0.5),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.add,
            size: 28,
            color: selected ? tokens.textOnPrimary : tokens.primaryBright,
          ),
        ),
      ),
    );
  }
}
