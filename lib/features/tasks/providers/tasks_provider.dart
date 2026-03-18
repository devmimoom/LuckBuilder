import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/models/mistake.dart';
import '../../mistakes/providers/mistakes_provider.dart';

enum TaskActionType {
  dueReview,
  weakSpot,
  captureNew,
}

class DailyTask {
  final String id;
  final String title;
  final String subtitle;
  final int estimateMinutes;
  final String ctaLabel;
  final TaskActionType actionType;
  final bool isCompleted;

  const DailyTask({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.estimateMinutes,
    required this.ctaLabel,
    required this.actionType,
    required this.isCompleted,
  });

  DailyTask copyWith({bool? isCompleted}) {
    return DailyTask(
      id: id,
      title: title,
      subtitle: subtitle,
      estimateMinutes: estimateMinutes,
      ctaLabel: ctaLabel,
      actionType: actionType,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class DailyTasksData {
  final String dateKey;
  final List<DailyTask> tasks;
  final int streakDays;

  const DailyTasksData({
    required this.dateKey,
    required this.tasks,
    required this.streakDays,
  });

  int get completedCount => tasks.where((task) => task.isCompleted).length;
  double get completionRate =>
      tasks.isEmpty ? 0 : completedCount / tasks.length;
}

final _taskRefreshProvider = StateProvider<int>((ref) => 0);

final todayTasksProvider = FutureProvider<DailyTasksData>((ref) async {
  ref.watch(_taskRefreshProvider);
  final mistakes = await ref.watch(allMistakesRawProvider.future);
  final prefs = await SharedPreferences.getInstance();
  final dateKey = _todayKey();
  final completedIds = prefs.getStringList(_completedKey(dateKey)) ?? const [];
  final tasks = _buildTasks(mistakes, completedIds.toSet());
  final streakDays = _calculateStreak(prefs);

  return DailyTasksData(
    dateKey: dateKey,
    tasks: tasks,
    streakDays: streakDays,
  );
});

final tasksControllerProvider = Provider<DailyTasksController>((ref) {
  return DailyTasksController(ref);
});

class DailyTasksController {
  DailyTasksController(this.ref);

  final Ref ref;

  Future<void> markTaskCompleted(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _todayKey();
    final completedKey = _completedKey(dateKey);
    final completedIds = prefs.getStringList(completedKey) ?? <String>[];

    if (!completedIds.contains(taskId)) {
      completedIds.add(taskId);
      await prefs.setStringList(completedKey, completedIds);
    }

    final mistakes = await ref.read(allMistakesRawProvider.future);
    final tasks = _buildTasks(mistakes, completedIds.toSet());
    final allDone = tasks.isNotEmpty && tasks.every((task) => task.isCompleted);
    await prefs.setBool(_dayDoneKey(dateKey), allDone);

    ref.read(_taskRefreshProvider.notifier).state++;
  }

  Future<void> resetTodayTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _todayKey();
    await prefs.remove(_completedKey(dateKey));
    await prefs.setBool(_dayDoneKey(dateKey), false);
    ref.read(_taskRefreshProvider.notifier).state++;
  }
}

List<DailyTask> _buildTasks(List<Mistake> mistakes, Set<String> completedIds) {
  final now = DateTime.now();
  final dueMistakes = mistakes.where((mistake) {
    final nextReviewAt = mistake.nextReviewAt;
    return nextReviewAt == null || !nextReviewAt.isAfter(now);
  }).toList();

  final weakGroup = _weakestGroup(mistakes);

  final tasks = <DailyTask>[
    DailyTask(
      id: 'due_review',
      title: '到期錯題複習',
      subtitle: dueMistakes.isEmpty
          ? '今天沒有到期複習，維持得很好'
          : '有 ${dueMistakes.length} 題該回來複習',
      estimateMinutes:
          dueMistakes.isEmpty ? 3 : (dueMistakes.length * 2).clamp(5, 20),
      ctaLabel: dueMistakes.isEmpty ? '查看' : '開始複習',
      actionType: TaskActionType.dueReview,
      isCompleted: completedIds.contains('due_review'),
    ),
    DailyTask(
      id: 'weak_spot',
      title: '弱點章節練習',
      subtitle: weakGroup == null ? '先累積幾題錯題，系統再幫你抓弱點' : '優先補強 ${weakGroup.$1}',
      estimateMinutes: 8,
      ctaLabel: '專攻弱點',
      actionType: TaskActionType.weakSpot,
      isCompleted: completedIds.contains('weak_spot'),
    ),
    DailyTask(
      id: 'capture_new',
      title: '拍題求助',
      subtitle: '遇到卡關題目時，直接拍照拆解步驟',
      estimateMinutes: 5,
      ctaLabel: '去拍題',
      actionType: TaskActionType.captureNew,
      isCompleted: completedIds.contains('capture_new'),
    ),
  ];

  return tasks;
}

(String, int)? _weakestGroup(List<Mistake> mistakes) {
  if (mistakes.isEmpty) return null;

  final groups = <String, List<Mistake>>{};
  for (final mistake in mistakes) {
    final key = '${mistake.subject} ${mistake.category}';
    groups.putIfAbsent(key, () => <Mistake>[]).add(mistake);
  }

  final sorted = groups.entries.toList()
    ..sort((a, b) {
      final aScore =
          a.value.fold<int>(0, (sum, item) => sum + item.masteryLevel) /
              a.value.length;
      final bScore =
          b.value.fold<int>(0, (sum, item) => sum + item.masteryLevel) /
              b.value.length;
      if (aScore != bScore) {
        return aScore.compareTo(bScore);
      }
      return b.value.length.compareTo(a.value.length);
    });

  if (sorted.isEmpty) return null;
  return (sorted.first.key, sorted.first.value.length);
}

int _calculateStreak(SharedPreferences prefs) {
  var streak = 0;
  var day = DateTime.now();

  while (true) {
    final dateKey = DateFormat('yyyy-MM-dd').format(day);
    final isDone = prefs.getBool(_dayDoneKey(dateKey)) ?? false;
    if (!isDone) break;
    streak++;
    day = day.subtract(const Duration(days: 1));
  }

  return streak;
}

String _todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());
String _completedKey(String dateKey) => 'daily_tasks_completed_$dateKey';
String _dayDoneKey(String dateKey) => 'daily_tasks_done_$dateKey';
