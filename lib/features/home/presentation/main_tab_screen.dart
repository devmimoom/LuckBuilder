import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_ux.dart';
import '../../../core/services/image_service.dart';
import '../../camera/presentation/multi_crop_screen.dart';
import '../../solver/presentation/solver_page.dart';
import '../../mistakes/presentation/mistakes_list_page.dart';

class MainTabScreen extends ConsumerStatefulWidget {
  const MainTabScreen({super.key});

  @override
  ConsumerState<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends ConsumerState<MainTabScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const SolverPage(),
    const MistakesListPage(),
  ];

  void _onCameraTapped() async {
    AppUX.feedbackClick();
    
    final File? image = await ImageService().pickAndCompressImage(context, fromCamera: true);
    
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
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: AppColors.background,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textTertiary,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.psychology_outlined),
              activeIcon: Icon(Icons.psychology),
              label: '解題分析',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_stories_outlined),
              activeIcon: Icon(Icons.auto_stories),
              label: '題庫',
            ),
          ],
        ),
      ),
    );
  }
}
