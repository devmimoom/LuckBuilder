import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

enum PushTimeMode { preset, custom }

enum PushContentMode { seq, mixNewReview, preferUnlearned, preferSaved }

class TimeRange {
  final TimeOfDay start; // inclusive
  final TimeOfDay end; // exclusive; can cross midnight
  const TimeRange(this.start, this.end);

  /// 勿擾關閉（start == end 時排程視為無勿擾時段）
  static const TimeRange noQuietHours = TimeRange(
    TimeOfDay(hour: 0, minute: 0),
    TimeOfDay(hour: 0, minute: 0),
  );

  Map<String, dynamic> toMap() => {
        'start': {'h': start.hour, 'm': start.minute},
        'end': {'h': end.hour, 'm': end.minute},
      };

  factory TimeRange.fromMap(Map<String, dynamic>? m) {
    if (m == null) {
      return const TimeRange(
          TimeOfDay(hour: 22, minute: 0), TimeOfDay(hour: 8, minute: 0));
    }
    final s = (m['start'] as Map?)?.cast<String, dynamic>() ?? {};
    final e = (m['end'] as Map?)?.cast<String, dynamic>() ?? {};
    return TimeRange(
      TimeOfDay(
          hour: ((s['h'] ?? 22) as num).toInt(),
          minute: ((s['m'] ?? 0) as num).toInt()),
      TimeOfDay(
          hour: ((e['h'] ?? 8) as num).toInt(),
          minute: ((e['m'] ?? 0) as num).toInt()),
    );
  }
}

/// 單一時間顯示：XX:XX（時、分皆兩位數）
String formatTimeOfDay(TimeOfDay t) {
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// 時間區間顯示：XX:XX - XX:XX（空格 + 連字號 + 空格）
String formatTimeRange(TimeRange r) {
  return '${formatTimeOfDay(r.start)} - ${formatTimeOfDay(r.end)}';
}

class PushConfig {
  final int freqPerDay; // 1..5
  final PushTimeMode timeMode;
  final List<String> presetSlots; // 7-9, 9-11, 11-13, 13-15, 15-17, 17-19, 19-21, 21-23
  final List<TimeOfDay> customTimes; // 1..5
  final Set<int> daysOfWeek; // 1..7
  final int minIntervalMinutes; // e.g. 120
  final PushContentMode contentMode;

  const PushConfig({
    required this.freqPerDay,
    required this.timeMode,
    required this.presetSlots,
    required this.customTimes,
    required this.daysOfWeek,
    required this.minIntervalMinutes,
    required this.contentMode,
  });

  static PushConfig defaults() => const PushConfig(
        freqPerDay: 1,
        timeMode: PushTimeMode.preset,
        presetSlots: ['21-23'], // 預設睡前（最不打擾）
        customTimes: [],
        daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
        minIntervalMinutes: 120,
        contentMode: PushContentMode.seq,
      );

  Map<String, dynamic> toMap() => {
        'freqPerDay': freqPerDay,
        'timeMode': timeMode.name,
        'presetSlots': presetSlots,
        'customTimes':
            customTimes.map((t) => {'h': t.hour, 'm': t.minute}).toList(),
        'daysOfWeek': daysOfWeek.toList(),
        'minIntervalMinutes': minIntervalMinutes,
        'contentMode': contentMode.name,
      };

  factory PushConfig.fromMap(Map<String, dynamic>? m) {
    if (m == null) return PushConfig.defaults();
    final tm = (m['timeMode'] ?? 'preset') as String;
    final cm = (m['contentMode'] ?? 'seq') as String;

    final customTimesRaw = m['customTimes'] as List<dynamic>? ?? [];
    final customTimes = customTimesRaw
        .whereType<Map>()
        .map((x) => TimeOfDay(
              hour: ((x['h'] ?? 21) as num).toInt(),
              minute: ((x['m'] ?? 40) as num).toInt(),
            ))
        .toList();
    
    final timeMode = PushTimeMode.values
        .firstWhere((e) => e.name == tm, orElse: () => PushTimeMode.preset);
    
    // 調試：確認解析結果
    if (kDebugMode && timeMode == PushTimeMode.custom) {
      final customTimesStr = customTimes
          .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
          .join(', ');
      debugPrint('📖 PushConfig.fromMap: 解析自訂時間模式');
      debugPrint('   - timeMode: $tm → $timeMode');
      debugPrint('   - customTimes 原始數據: $customTimesRaw');
      debugPrint('   - customTimes 解析結果: [$customTimesStr] (數量: ${customTimes.length})');
      if (customTimes.isEmpty && timeMode == PushTimeMode.custom) {
        debugPrint('   ⚠️ 警告：timeMode 為 custom 但 customTimes 為空！');
      }
    }

    return PushConfig(
      freqPerDay: ((m['freqPerDay'] ?? 1) as num).toInt().clamp(1, 5),
      timeMode: timeMode,
      presetSlots: (m['presetSlots'] as List<dynamic>? ?? ['21-23'])
          .map((e) => e.toString())
          .toList(),
      customTimes: customTimes.take(5).toList(),
      daysOfWeek: (m['daysOfWeek'] as List<dynamic>? ?? [1, 2, 3, 4, 5, 6, 7])
          .map((e) => (e as num).toInt())
          .toSet(),
      minIntervalMinutes:
          ((m['minIntervalMinutes'] ?? 120) as num).toInt().clamp(30, 24 * 60),
      contentMode: PushContentMode.values
          .firstWhere((e) => e.name == cm, orElse: () => PushContentMode.seq),
    );
  }

  PushConfig copyWith({
    int? freqPerDay,
    PushTimeMode? timeMode,
    List<String>? presetSlots,
    List<TimeOfDay>? customTimes,
    Set<int>? daysOfWeek,
    int? minIntervalMinutes,
    PushContentMode? contentMode,
  }) {
    return PushConfig(
      freqPerDay: freqPerDay ?? this.freqPerDay,
      timeMode: timeMode ?? this.timeMode,
      presetSlots: presetSlots ?? this.presetSlots,
      customTimes: customTimes ?? this.customTimes,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      minIntervalMinutes: minIntervalMinutes ?? this.minIntervalMinutes,
      contentMode: contentMode ?? this.contentMode,
    );
  }
}
