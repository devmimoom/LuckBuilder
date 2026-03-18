import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/services/gemini_service.dart' hide debugPrint;
import 'features/home/presentation/main_tab_screen.dart';

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '錯題解析助手',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainTabScreen(),
    );
  }
}
