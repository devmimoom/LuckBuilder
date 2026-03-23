import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/home_background_preset.dart';

const _prefsKey = 'home_background_preset_id';

final homeBackgroundPresetProvider =
    StateNotifierProvider<HomeBackgroundPresetNotifier, HomeBackgroundPreset>(
  (ref) => HomeBackgroundPresetNotifier(),
);

class HomeBackgroundPresetNotifier extends StateNotifier<HomeBackgroundPreset> {
  HomeBackgroundPresetNotifier() : super(HomeBackgroundPresets.defaultPreset) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final parsed =
          HomeBackgroundPresets.tryParseId(prefs.getString(_prefsKey));
      if (parsed != null) {
        state = parsed;
      }
    } catch (_) {
      // 保持預設
    }
  }

  Future<void> select(HomeBackgroundPresetId id) async {
    final preset = HomeBackgroundPresets.byId(id);
    state = preset;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, id.name);
    } catch (_) {
      // 仍保留記憶體狀態
    }
  }
}
