import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_ux.dart';
import '../../../core/utils/paywall_gate.dart';
import '../../../core/services/image_service.dart';
import '../../camera/presentation/multi_crop_screen.dart';
import '../../mistakes/presentation/mistakes_list_page.dart';
import '../../subscription/providers/feature_trial_provider.dart';
import 'home_feature_hub_page.dart';

class MainTabScreen extends ConsumerStatefulWidget {
  const MainTabScreen({super.key});

  @override
  ConsumerState<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends ConsumerState<MainTabScreen> {
  int _currentIndex = 0;
  bool _isNavVisible = true;

  void _setNavVisible(bool visible) {
    if (_isNavVisible == visible) return;
    setState(() => _isNavVisible = visible);
  }

  void _onCameraTapped() async {
    if (!await PaywallGate.guardFeatureAccess(
      context,
      ref,
      TrialFeature.cameraSolve,
    )) {
      return;
    }
    if (!mounted) return;
    AppUX.feedbackClick();

    final File? image =
        await ImageService().pickAndCompressImage(context, fromCamera: true);

    if (image != null) {
      if (mounted) {
        AppUX.feedbackSuccess();
        Navigator.of(context).push(
          AppUX.fadeRoute(MultiCropScreen(imageFile: image)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeFeatureHubPage(
        onOpenMistakesTab: () => setState(() => _currentIndex = 1),
      ),
      const MistakesListPage(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis != Axis.vertical) return false;
          if (notification.direction == ScrollDirection.reverse) {
            _setNavVisible(false);
          } else if (notification.direction == ScrollDirection.forward) {
            _setNavVisible(true);
          }
          return false;
        },
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: AnimatedSlide(
        offset: _isNavVisible ? Offset.zero : const Offset(0, 0.25),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _isNavVisible ? 1 : 0.6,
          duration: const Duration(milliseconds: 180),
          child: Container(
            margin: const EdgeInsets.only(top: 30), // 微調按鈕位置，避免遮擋
            height: 64,
            width: 64,
            child: FloatingActionButton(
              onPressed: _onCameraTapped,
              backgroundColor: AppColors.textPrimary,
              shape: const CircleBorder(),
              elevation: 4,
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Builder(
            builder: (context) {
              const expandedHeight = 72.0;
              const collapsedHeight = 36.0;
              final bottomInset = MediaQuery.of(context).padding.bottom;
              final barHeight =
                  (_isNavVisible ? expandedHeight : collapsedHeight) + bottomInset;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                height: barHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4EEF1).withValues(alpha: 0.9),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: const Color(0xFFCDBFC6).withValues(alpha: 0.75),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    child: SizedBox(
                      height: _isNavVisible ? expandedHeight : collapsedHeight,
                      child: Row(
                        children: [
                          Expanded(
                            child: _NavItem(
                              icon: Icons.home_outlined,
                              activeIcon: Icons.home,
                              selected: _currentIndex == 0,
                              onTap: () {
                                _setNavVisible(true);
                                setState(() => _currentIndex = 0);
                              },
                            ),
                          ),
                          const SizedBox(width: 84),
                          Expanded(
                            child: _NavItem(
                              icon: Icons.auto_stories_outlined,
                              activeIcon: Icons.auto_stories,
                              selected: _currentIndex == 1,
                              onTap: () {
                                _setNavVisible(true);
                                setState(() => _currentIndex = 1);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF8F7686);
    const inactiveColor = Color(0xFFB7A8B1);
    final color = selected ? activeColor : inactiveColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 24),
          ],
        ),
      ),
    );
  }
}
