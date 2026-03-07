import 'package:flutter/material.dart';
import '../../bubble_library/models/user_library.dart';
import '../../localization/app_language.dart';
import '../../localization/app_strings.dart';

String pushHintFor(UserLibraryProduct lp, AppLanguage lang) {
  final cfg = lp.pushConfig;

  final freq = cfg.freqPerDay.clamp(1, 5);
  final perDay = uiString(lang, 'push_hint_per_day').replaceFirst('{n}', '$freq');
  final mode = cfg.timeMode.name == 'custom'
      ? uiString(lang, 'time_mode_custom')
      : uiString(lang, 'time_mode_preset');

  String slotLabel(String s) {
    switch (s) {
      case 'morning':
        return uiString(lang, 'slot_morning');
      case 'noon':
        return uiString(lang, 'slot_noon');
      case 'evening':
        return uiString(lang, 'slot_evening');
      case 'night':
        return uiString(lang, 'slot_night');
      default:
        return s;
    }
  }

  String tod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String timesText() {
    if (cfg.timeMode.name == 'custom' && cfg.customTimes.isNotEmpty) {
      final list = List<TimeOfDay>.from(cfg.customTimes);
      list.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
      final shown = list.take(5).map(tod).join('、');
      return uiString(lang, 'custom_times_display').replaceFirst('{times}', shown);
    }

    final slots = cfg.presetSlots.isEmpty ? ['night'] : cfg.presetSlots;
    final shown = slots.take(4).map(slotLabel).join('·');
    return uiString(lang, 'slot_times_display').replaceFirst('{slots}', shown);
  }

  return '$perDay · $mode · ${timesText()}';
}
