import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/models/mistake.dart';
import '../../mistakes/providers/mistakes_provider.dart';

class DailyMistakeActivity {
  final DateTime date;
  final int count;

  const DailyMistakeActivity({
    required this.date,
    required this.count,
  });
}

class SubjectInsight {
  final String subject;
  final int totalCount;
  final int dueCount;
  final int masteredCount;

  const SubjectInsight({
    required this.subject,
    required this.totalCount,
    required this.dueCount,
    required this.masteredCount,
  });

  double get masteredRate => totalCount == 0 ? 0 : masteredCount / totalCount;
}

class CategoryWeaknessInsight {
  final String subject;
  final String category;
  final int totalCount;
  final int dueCount;
  final double averageMastery;

  const CategoryWeaknessInsight({
    required this.subject,
    required this.category,
    required this.totalCount,
    required this.dueCount,
    required this.averageMastery,
  });
}

class LearningInsightsData {
  final int totalMistakes;
  final int dueCount;
  final int masteredCount;
  final int learningCount;
  final int newThisWeekCount;
  final double averageMastery;
  final List<DailyMistakeActivity> recentActivity;
  final List<SubjectInsight> subjectInsights;
  final List<CategoryWeaknessInsight> weakCategories;

  const LearningInsightsData({
    required this.totalMistakes,
    required this.dueCount,
    required this.masteredCount,
    required this.learningCount,
    required this.newThisWeekCount,
    required this.averageMastery,
    required this.recentActivity,
    required this.subjectInsights,
    required this.weakCategories,
  });
}

final learningInsightsProvider = FutureProvider<LearningInsightsData>((
  ref,
) async {
  final mistakes = await ref.watch(allMistakesRawProvider.future);
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final weekStart = todayStart.subtract(const Duration(days: 6));

  final dueCount = mistakes.where((mistake) {
    final nextReviewAt = mistake.nextReviewAt;
    return nextReviewAt == null || !nextReviewAt.isAfter(now);
  }).length;

  final masteredCount =
      mistakes.where((mistake) => mistake.masteryLevel >= 2).length;
  final learningCount =
      mistakes.where((mistake) => mistake.masteryLevel == 1).length;
  final newThisWeekCount = mistakes
      .where((mistake) => !mistake.createdAt.isBefore(weekStart))
      .length;
  final averageMastery = mistakes.isEmpty
      ? 0.0
      : mistakes.fold<int>(0, (sum, item) => sum + item.masteryLevel) /
          mistakes.length;

  final recentActivity = List.generate(7, (index) {
    final date = weekStart.add(Duration(days: index));
    final nextDate = date.add(const Duration(days: 1));
    final count = mistakes.where((mistake) {
      return !mistake.createdAt.isBefore(date) &&
          mistake.createdAt.isBefore(nextDate);
    }).length;
    return DailyMistakeActivity(date: date, count: count);
  });

  final groupedBySubject = <String, List<Mistake>>{};
  for (final mistake in mistakes) {
    groupedBySubject
        .putIfAbsent(mistake.subject, () => <Mistake>[])
        .add(mistake);
  }
  final subjectInsights = groupedBySubject.entries.map((entry) {
    final items = entry.value;
    final due = items.where((mistake) {
      final nextReviewAt = mistake.nextReviewAt;
      return nextReviewAt == null || !nextReviewAt.isAfter(now);
    }).length;
    final mastered = items.where((mistake) => mistake.masteryLevel >= 2).length;
    return SubjectInsight(
      subject: entry.key,
      totalCount: items.length,
      dueCount: due,
      masteredCount: mastered,
    );
  }).toList()
    ..sort((a, b) => b.totalCount.compareTo(a.totalCount));

  final groupedByCategory = <String, List<Mistake>>{};
  for (final mistake in mistakes) {
    final key = '${mistake.subject}__${mistake.category}';
    groupedByCategory.putIfAbsent(key, () => <Mistake>[]).add(mistake);
  }
  final weakCategories = groupedByCategory.entries.map((entry) {
    final items = entry.value;
    final sample = items.first;
    final due = items.where((mistake) {
      final nextReviewAt = mistake.nextReviewAt;
      return nextReviewAt == null || !nextReviewAt.isAfter(now);
    }).length;
    final avgMastery =
        items.fold<int>(0, (sum, item) => sum + item.masteryLevel) /
            items.length;
    return CategoryWeaknessInsight(
      subject: sample.subject,
      category: sample.category,
      totalCount: items.length,
      dueCount: due,
      averageMastery: avgMastery,
    );
  }).toList()
    ..sort((a, b) {
      final dueCompare = b.dueCount.compareTo(a.dueCount);
      if (dueCompare != 0) return dueCompare;
      final masteryCompare = a.averageMastery.compareTo(b.averageMastery);
      if (masteryCompare != 0) return masteryCompare;
      return b.totalCount.compareTo(a.totalCount);
    });

  return LearningInsightsData(
    totalMistakes: mistakes.length,
    dueCount: dueCount,
    masteredCount: masteredCount,
    learningCount: learningCount,
    newThisWeekCount: newThisWeekCount,
    averageMastery: averageMastery,
    recentActivity: recentActivity,
    subjectInsights: subjectInsights,
    weakCategories: weakCategories.take(5).toList(),
  );
});
