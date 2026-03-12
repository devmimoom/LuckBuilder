import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';

import 'theme/theme_controller.dart';
import 'theme/app_themes.dart';
import 'theme/app_theme_id.dart';
import 'pages/welcome/onboarding_store.dart';
import 'iap/credits_iap_service.dart';
import 'localization/app_language.dart';
import 'localization/app_strings.dart';

/// Flutter 啟動後進行初始化（Firebase、主題、hasSeenOnboarding），完成後透過 [builder] 建立正式 app。
class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({
    super.key,
    required this.builder,
  });

  final Widget Function(ThemeController themeController, bool initialHasSeenOnboarding, AppLanguage initialLang) builder;

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  bool _isReady = false;
  Object? _error;
  ThemeController? _themeController;
  bool _initialHasSeenOnboarding = false;
  AppLanguage _initialLang = AppLanguage.en;
  bool _firebaseReady = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      // 1) 本地初始化：主題、語言與 onboarding 狀態（快速、離線）
      final themeController = ThemeController();
      await themeController.init();
      final initialHasSeenOnboarding = await hasSeenOnboarding();
      final initialLang = await loadSavedLanguage();

      // 2) 最小阻塞的 Firebase 初始化（帶超時），避免 UI 因遠端卡住
      await _initFirebaseCore();

      if (!mounted) return;
      setState(() {
        _themeController = themeController;
        _initialHasSeenOnboarding = initialHasSeenOnboarding;
        _initialLang = initialLang;
        _isReady = true;
        _error = null;
      });

      // 3) 遠端服務暖機：匿名登入、IAP、Analytics，改為背景執行
      unawaited(_warmServices());
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('Bootstrap error: $e');
        debugPrint(stack.toString());
      }
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = detectSystemLanguage();
    if (_error != null) {
      return MaterialApp(
        title: 'OnePop',
        debugShowCheckedModeBanner: false,
        theme: AppThemes.byId(AppThemeId.darkNeon),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    uiString(lang, 'load_error'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_error',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      setState(() => _error = null);
                      _bootstrap();
                    },
                    child: Text(uiString(lang, 'retry')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_isReady) {
      return const _BrandedPreloadScreen();
    }

    return widget.builder(_themeController!, _initialHasSeenOnboarding, _initialLang);
  }

  Future<bool> _initFirebaseCore() async {
    final app = await _runWithTimeout<FirebaseApp>(
      () => Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
      const Duration(seconds: 5),
      logLabel: 'Firebase.initializeApp',
    );
    final success = app != null;
    _firebaseReady = success;
    return success;
  }

  Future<void> _warmServices() async {
    try {
      // 確保 Firebase 已初始化（若前一步超時則再試一次）
      if (!_firebaseReady) {
        final ok = await _initFirebaseCore();
        if (!ok) return;
      }

      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await _runWithTimeout(
          () async => auth.signInAnonymously(),
          const Duration(seconds: 4),
          logLabel: 'Anonymous sign-in',
        );
      }

      final user = auth.currentUser;
      if (user != null) {
        await _runWithTimeout(
          () => CreditsIAPService.configure(user.uid),
          const Duration(seconds: 6),
          logLabel: 'CreditsIAPService.configure',
        );
        await _runWithTimeout(
          () => FirebaseAnalytics.instance.setUserId(id: user.uid),
          const Duration(seconds: 2),
          logLabel: 'FirebaseAnalytics.setUserId',
        );
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('Warm services error: $e');
        debugPrint(stack.toString());
      }
    }
  }

  Future<T?> _runWithTimeout<T>(
    Future<T> Function() task,
    Duration timeout, {
    String logLabel = 'task',
  }) async {
    try {
      return await task().timeout(timeout);
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('$logLabel timeout after ${timeout.inSeconds}s');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('$logLabel failed: $e');
        debugPrint(stack.toString());
      }
    }
    return null;
  }
}

class _BrandedPreloadScreen extends StatelessWidget {
  const _BrandedPreloadScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OnePop',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.byId(AppThemeId.darkNeon),
      home: const Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0A0E27),
                Color(0xFF1A1A3A),
                Color(0xFF0F1629),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'OnePop',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                      letterSpacing: 6,
                      shadows: [
                        Shadow(
                          color: Colors.black38,
                          offset: Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Your mental snack',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
