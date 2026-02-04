import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';

import 'app_scaffold.dart';
import 'bubble_library/bootstrapper.dart';
import 'iap/credits_iap_service.dart';
import 'theme/theme_controller.dart';
import 'theme/app_themes.dart';
import 'navigation/app_nav.dart';
import 'pages/welcome/bubble_welcome_page.dart';
import 'pages/welcome/onboarding_screen.dart';
import 'pages/welcome/onboarding_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // ✅ 時區初始化已移至 BubbleBootstrapper，避免與插件註冊衝突

  // 自動匿名登入（如果尚未登入）
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    try {
      final userCredential = await auth.signInAnonymously();
      debugPrint('匿名登入成功: uid=${userCredential.user?.uid}');
    } catch (e) {
      // 如果匿名登入失敗，記錄錯誤但不阻止應用程式啟動
      debugPrint('匿名登入失敗: $e');
    }
  } else {
    debugPrint('用戶已登入: uid=${auth.currentUser?.uid}');
  }

  if (auth.currentUser != null) {
    await CreditsIAPService.configure(auth.currentUser!.uid);
    await FirebaseAnalytics.instance.setUserId(id: auth.currentUser!.uid);
  }

  // 初始化主題控制器
  final themeController = ThemeController();
  await themeController.init();

  runApp(ProviderScope(child: MyApp(themeController: themeController)));
}

class MyApp extends StatelessWidget {
  final ThemeController themeController;
  const MyApp({super.key, required this.themeController});

  @override
  Widget build(BuildContext context) {
    return _AppRoot(themeController: themeController);
  }
}

/// Root gate: shows onboarding when not seen, then Welcome or Main based on flow B.
class _AppRoot extends StatefulWidget {
  final ThemeController themeController;

  const _AppRoot({required this.themeController});

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool? _hasSeenOnboarding;
  bool _showWelcomePage = false;

  @override
  void initState() {
    super.initState();
    hasSeenOnboarding().then((value) {
      if (mounted) {
        setState(() {
          _hasSeenOnboarding = value;
          // 每次啟動都先顯示 Welcome，點擊後才進入 Main
          if (value) _showWelcomePage = true;
        });
      }
    });
  }

  void _onOnboardingComplete() {
    setState(() {
      _hasSeenOnboarding = true;
      _showWelcomePage = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeController = widget.themeController;

    if (_hasSeenOnboarding == null) {
      return MaterialApp(
        title: 'OnePop',
        debugShowCheckedModeBanner: false,
        theme: AppThemes.byId(themeController.id),
        home: const Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A0E27), Color(0xFF1A1F3A)],
              ),
            ),
          ),
        ),
      );
    }

    if (_hasSeenOnboarding == false) {
      return AnimatedBuilder(
        animation: themeController,
        builder: (_, __) {
          return MaterialApp(
            title: 'OnePop',
            debugShowCheckedModeBanner: false,
            theme: AppThemes.byId(themeController.id),
            home: OnboardingScreen(onComplete: _onOnboardingComplete),
          );
        },
      );
    }

    // _hasSeenOnboarding == true: show Welcome once after onboarding, then Main on later launches
    return BubbleBootstrapper(
      child: AnimatedBuilder(
        animation: themeController,
        builder: (_, __) {
          return MaterialApp(
            navigatorKey: rootNavKey,
            title: 'OnePop',
            debugShowCheckedModeBanner: false,
            theme: AppThemes.byId(themeController.id),
            home: _showWelcomePage
                ? BubbleWelcomePage(
                    onFinished: () {
                      setState(() => _showWelcomePage = false);
                      rootNavKey.currentState?.pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => MainScaffold4Tabs(
                              themeController: themeController),
                        ),
                      );
                    },
                  )
                : MainScaffold4Tabs(themeController: themeController),
          );
        },
      ),
    );
  }
}
