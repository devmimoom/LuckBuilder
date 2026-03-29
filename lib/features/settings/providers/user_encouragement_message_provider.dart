import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'user_encouragement_message';

/// 未自訂或清空時，首頁工具分頁顯示的預設鼓勵語。
const defaultUserEncouragementMessage = '歡迎來到LuckLab, 在這裡越努力越幸運～';

final userEncouragementMessageProvider =
    StateNotifierProvider<UserEncouragementMessageNotifier, String>(
  (ref) => UserEncouragementMessageNotifier(),
);

class UserEncouragementMessageNotifier extends StateNotifier<String> {
  UserEncouragementMessageNotifier() : super(defaultUserEncouragementMessage) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey)?.trim();
      if (saved != null && saved.isNotEmpty) {
        state = saved;
      }
    } catch (_) {
      // Keep default when loading fails.
    }
  }

  /// 清空或只空白時恢復預設文案，並清除儲存。
  Future<void> setMessage(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      state = defaultUserEncouragementMessage;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefsKey);
      } catch (_) {}
      return;
    }
    state = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, normalized);
    } catch (_) {}
  }
}
