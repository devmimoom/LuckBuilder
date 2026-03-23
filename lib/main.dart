import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/services/gemini_service.dart' hide debugPrint;
import 'features/home/presentation/main_tab_screen.dart';
import 'features/review/presentation/review_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 載入環境變數（使用 try-catch 確保不會阻塞啟動）
  try {
    await dotenv.load(fileName: ".env");

    // 檢查 Gemini API Key（現在使用 Gemini 進行 OCR，不再需要 Mathpix）
    final geminiKey = dotenv.get('GEMINI_API_KEY', fallback: '');
    if (geminiKey.isEmpty) {
      debugPrint("⚠️ 警告: GEMINI_API_KEY 未設定");
    } else {
      debugPrint("✅ Gemini API Key 已載入");
    }
  } catch (e) {
    debugPrint("❌ 載入 .env 檔案失敗: $e");
    debugPrint("   請確認專案根目錄有 .env 檔案");
    debugPrint("   應用將繼續運行，但 API 功能可能無法使用");
  }

  // 2. 初始化 AI 服務（等待初始化完成，但設置超時避免阻塞太久）
  try {
    await GeminiService().init().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint("⚠️ GeminiService 初始化超時（10秒），將在後台繼續嘗試");
        // 不拋出錯誤，讓應用繼續啟動
      },
    );
    debugPrint("✅ GeminiService 初始化流程完成");
  } catch (e) {
    debugPrint("❌ GeminiService 初始化失敗: $e");
    debugPrint("   應用將繼續運行，但 AI 功能可能無法使用");
  }

  // 3. 啟動應用（確保一定會執行）
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }

  Future<void> _initAppLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleIncomingUri(initial);
        });
      }
    } catch (_) {}

    _linkSub = _appLinks.uriLinkStream.listen(_handleIncomingUri);
  }

  void _handleIncomingUri(Uri uri) {
    if (uri.scheme != 'luckbuilder') return;

    final path = uri.host.isNotEmpty ? uri.host : uri.path.replaceAll('/', '');
    if (path != 'review') return;

    final context = _navigatorKey.currentContext;
    if (context == null) return;

    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => const ReviewPage(),
      ),
    );
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '錯題解析助手',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: _navigatorKey,
      home: const MainTabScreen(),
    );
  }
}
