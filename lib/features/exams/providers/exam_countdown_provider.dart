import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/widget_sync_service.dart';

// ---------------------------------------------------------------------------
// Model — 只需要名稱 + 日期，type 保留供 widget sync 分類用
// ---------------------------------------------------------------------------

enum ExamType { monthly, mock, cap, gsat, custom }

// 預設快速填入選項
const List<String> kExamPresets = ['段考', '模考', '會考', '學測'];

class ExamCountdown {
  const ExamCountdown({
    required this.id,
    required this.name,
    required this.examDate,
    this.type = ExamType.custom,
  });

  final String id;
  final String name;
  final DateTime examDate;
  final ExamType type;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'examDate': examDate.toIso8601String(),
        'type': type.name,
      };

  factory ExamCountdown.fromMap(Map<String, dynamic> map) {
    return ExamCountdown(
      id: map['id'] as String,
      // 向下相容：舊版存 typeLabel，沒有獨立 name 欄位時 fallback
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : (map['typeLabel'] as String?)?.trim() ?? '考試',
      examDate: DateTime.parse(map['examDate'] as String),
      type: ExamType.values.firstWhere(
        (v) => v.name == (map['type'] as String?),
        orElse: () => ExamType.custom,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data container
// ---------------------------------------------------------------------------

class ExamCountdownData {
  const ExamCountdownData({required this.exams});

  final List<ExamCountdown> exams;

  ExamCountdown? get nextExam {
    final today = _today;
    for (final exam in exams) {
      final d =
          DateTime(exam.examDate.year, exam.examDate.month, exam.examDate.day);
      if (!d.isBefore(today)) return exam;
    }
    return exams.isEmpty ? null : exams.first;
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _examRefreshProvider = StateProvider<int>((ref) => 0);

final examCountdownProvider = FutureProvider<ExamCountdownData>((ref) async {
  ref.watch(_examRefreshProvider);
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList(_kStorageKey) ?? const <String>[];

  final exams = raw
      .map((item) => ExamCountdown.fromMap(jsonDecode(item)))
      .toList()
    ..sort((a, b) => a.examDate.compareTo(b.examDate));

  await _syncWidget(exams);
  return ExamCountdownData(exams: exams);
});

final examCountdownControllerProvider =
    Provider<ExamCountdownController>((ref) => ExamCountdownController(ref));

class ExamCountdownController {
  ExamCountdownController(this.ref);
  final Ref ref;

  Future<void> saveExam(ExamCountdown exam) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _read(prefs);
    final idx = list.indexWhere((e) => e.id == exam.id);
    if (idx >= 0) {
      list[idx] = exam;
    } else {
      list.add(exam);
    }
    list.sort((a, b) => a.examDate.compareTo(b.examDate));
    await _persist(prefs, list);
    ref.read(_examRefreshProvider.notifier).state++;
  }

  Future<void> deleteExam(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _read(prefs)
      ..removeWhere((e) => e.id == id);
    await _persist(prefs, list);
    ref.read(_examRefreshProvider.notifier).state++;
  }

  Future<void> seedIfEmpty() async {
    final prefs = await SharedPreferences.getInstance();
    if ((await _read(prefs)).isNotEmpty) return;
    final now = DateTime.now();
    await _persist(prefs, [
      ExamCountdown(
        id: 'seed_monthly',
        name: '段考',
        type: ExamType.monthly,
        examDate: DateTime(now.year, now.month, now.day + 14),
      ),
      ExamCountdown(
        id: 'seed_cap',
        name: '會考',
        type: ExamType.cap,
        examDate: DateTime(now.year, now.month, now.day + 48),
      ),
    ]);
    ref.read(_examRefreshProvider.notifier).state++;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<List<ExamCountdown>> _read(SharedPreferences prefs) async {
  final raw = prefs.getStringList(_kStorageKey) ?? const <String>[];
  return raw.map((item) => ExamCountdown.fromMap(jsonDecode(item))).toList();
}

Future<void> _persist(SharedPreferences prefs, List<ExamCountdown> list) async {
  await prefs.setStringList(
      _kStorageKey, list.map((e) => jsonEncode(e.toMap())).toList());
  await _syncWidget(list);
}

Future<void> _syncWidget(List<ExamCountdown> list) async {
  final sorted = [...list]..sort((a, b) => a.examDate.compareTo(b.examDate));
  final today = _today;
  ExamCountdown? next;
  for (final e in sorted) {
    final d = DateTime(e.examDate.year, e.examDate.month, e.examDate.day);
    if (!d.isBefore(today)) {
      next = e;
      break;
    }
  }
  if (next == null) {
    await WidgetSyncService.syncEmptyWidget();
    return;
  }
  final diff =
      DateTime(next.examDate.year, next.examDate.month, next.examDate.day)
          .difference(today)
          .inDays;
  await WidgetSyncService.syncExamCountdownWidget(
    title: next.name,
    value: diff <= 0 ? '今天' : 'D-$diff',
    subtitle: '${DateFormat('MM/dd').format(next.examDate)} · 點一下直接進入複習',
  );
}

String examCountdownLabel(ExamCountdown exam) {
  final diff =
      DateTime(exam.examDate.year, exam.examDate.month, exam.examDate.day)
          .difference(_today)
          .inDays;
  if (diff > 0) return 'D-$diff';
  if (diff == 0) return '今天';
  return '已過 ${diff.abs()} 天';
}

DateTime get _today {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

const String _kStorageKey = 'exam_countdowns_v1';
