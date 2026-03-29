import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'user_display_name';
const defaultUserDisplayName = 'Ariel';

/// 儲存值為空白時，首頁等處仍顯示預設稱呼（輸入框可暫時清空再重打）。
String userDisplayNameForGreeting(String stored) {
  final t = stored.trim();
  return t.isEmpty ? defaultUserDisplayName : t;
}

final userDisplayNameProvider =
    StateNotifierProvider<UserDisplayNameNotifier, String>(
  (ref) => UserDisplayNameNotifier(),
);

class UserDisplayNameNotifier extends StateNotifier<String> {
  UserDisplayNameNotifier() : super(defaultUserDisplayName) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_prefsKey)) return;
      final saved = prefs.getString(_prefsKey);
      state = (saved ?? '').trim();
    } catch (_) {
      // Keep default name when loading fails.
    }
  }

  Future<void> setName(String value) async {
    final nextValue = value.trim();
    state = nextValue;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, nextValue);
    } catch (_) {
      // Keep in-memory value even if persistence fails.
    }
  }
}
