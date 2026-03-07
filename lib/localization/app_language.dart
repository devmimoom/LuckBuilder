import 'dart:ui' show PlatformDispatcher;

import 'package:shared_preferences/shared_preferences.dart';

/// App 支援的顯示語言
enum AppLanguage {
  zhTw,
  en,
}

const _kLangKey = 'app_language';

/// 依系統 Locale 推測預設語言
AppLanguage detectSystemLanguage() {
  try {
    final locale = PlatformDispatcher.instance.locale;
    if (locale.languageCode == 'zh') return AppLanguage.zhTw;
  } catch (_) {}
  return AppLanguage.en;
}

/// 從 SharedPreferences 讀取已儲存的語言設定；若無則 fallback 系統語言。
Future<AppLanguage> loadSavedLanguage() async {
  try {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kLangKey);
    if (raw == AppLanguage.zhTw.name) return AppLanguage.zhTw;
    if (raw == AppLanguage.en.name) return AppLanguage.en;
  } catch (_) {}
  return detectSystemLanguage();
}

/// 將語言設定寫入 SharedPreferences。
Future<void> saveLanguage(AppLanguage lang) async {
  try {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLangKey, lang.name);
  } catch (_) {}
}

/// 回傳標準化語言代碼字串（可供日後記錄到 Firestore 或偏好設定）
String appLanguageCode(AppLanguage lang) {
  switch (lang) {
    case AppLanguage.zhTw:
      return 'zh-TW';
    case AppLanguage.en:
      return 'en';
  }
}

/// 回傳設定頁／選單顯示用的語言名稱
String appLanguageDisplayName(AppLanguage lang) {
  switch (lang) {
    case AppLanguage.zhTw:
      return '繁體中文';
    case AppLanguage.en:
      return 'English';
  }
}

