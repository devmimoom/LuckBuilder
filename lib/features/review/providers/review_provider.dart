import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/models/mistake.dart';
import '../../mistakes/providers/mistakes_provider.dart';

enum ReviewMode {
  quick,
  standard,
  weakSpot,
}

enum ReviewOutcome {
  mastered,
  almost,
  retry,
}

class ReviewSummary {
  final int dueCount;
  final int reviewedTodayCount;
  final int masteredCount;

  const ReviewSummary({
    required this.dueCount,
    required this.reviewedTodayCount,
    required this.masteredCount,
  });
}

class ReviewQueues {
  final List<Mistake> due;
  final List<Mistake> quick;
  final List<Mistake> standard;
  final List<Mistake> weakSpot;
  final String weakSpotLabel;

  const ReviewQueues({
    required this.due,
    required this.quick,
    required this.standard,
    required this.weakSpot,
    required this.weakSpotLabel,
  });
}

class ReviewSessionState {
  final List<Mistake> queue;
  final int currentIndex;
  final bool showAnswer;
  final bool isSubmitting;
  final Map<int, ReviewOutcome> outcomes;

  const ReviewSessionState({
    this.queue = const [],
    this.currentIndex = 0,
    this.showAnswer = false,
    this.isSubmitting = false,
    this.outcomes = const {},
  });

  bool get hasStarted => queue.isNotEmpty;
  bool get isFinished => hasStarted && currentIndex >= queue.length;
  int get completedCount => outcomes.length;

  Mistake? get currentMistake {
    if (!hasStarted || isFinished) return null;
    return queue[currentIndex];
  }

  ReviewSessionState copyWith({
    List<Mistake>? queue,
    int? currentIndex,
    bool? showAnswer,
    bool? isSubmitting,
    Map<int, ReviewOutcome>? outcomes,
  }) {
    return ReviewSessionState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      showAnswer: showAnswer ?? this.showAnswer,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      outcomes: outcomes ?? this.outcomes,
    );
  }
}

final reviewSummaryProvider = FutureProvider<ReviewSummary>((ref) async {
  final mistakes = await ref.watch(allMistakesRawProvider.future);
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);

  final due = mistakes.where((mistake) {
    final nextReviewAt = mistake.nextReviewAt;
    return nextReviewAt == null || !nextReviewAt.isAfter(now);
  }).length;

  final reviewedToday = mistakes.where((mistake) {
    final lastReviewedAt = mistake.lastReviewedAt;
    return lastReviewedAt != null && !lastReviewedAt.isBefore(todayStart);
  }).length;

  final mastered =
      mistakes.where((mistake) => mistake.masteryLevel >= 2).length;

  return ReviewSummary(
    dueCount: due,
    reviewedTodayCount: reviewedToday,
    masteredCount: mastered,
  );
});

final reviewQueuesProvider = FutureProvider<ReviewQueues>((ref) async {
  final mistakes = await ref.watch(allMistakesRawProvider.future);
  final now = DateTime.now();

  final due = [...mistakes]..sort((a, b) {
      final aTime = a.nextReviewAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.nextReviewAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });

  final dueMistakes = due.where((mistake) {
    final nextReviewAt = mistake.nextReviewAt;
    return nextReviewAt == null || !nextReviewAt.isAfter(now);
  }).toList();

  final weakSpot = [
    ...mistakes.where(
        (mistake) => mistake.masteryLevel < 2 || mistake.reviewCount == 0),
  ]..sort((a, b) {
      final masteryCompare = a.masteryLevel.compareTo(b.masteryLevel);
      if (masteryCompare != 0) return masteryCompare;
      return b.reviewCount.compareTo(a.reviewCount);
    });

  final weakSpotQueue = weakSpot.take(10).toList();
  final weakSpotLabel = weakSpotQueue.isEmpty
      ? '目前沒有弱點資料'
      : '${weakSpotQueue.first.subject} ${weakSpotQueue.first.category}';

  return ReviewQueues(
    due: dueMistakes,
    quick: dueMistakes.take(5).toList(),
    standard: dueMistakes.take(10).toList(),
    weakSpot: weakSpotQueue,
    weakSpotLabel: weakSpotLabel,
  );
});

class ReviewSessionController extends StateNotifier<ReviewSessionState> {
  ReviewSessionController(this.ref) : super(const ReviewSessionState());

  final Ref ref;

  void start(List<Mistake> mistakes) {
    state = ReviewSessionState(queue: mistakes);
  }

  void reset() {
    state = const ReviewSessionState();
  }

  void revealAnswer() {
    if (!state.hasStarted || state.isFinished) return;
    state = state.copyWith(showAnswer: true);
  }

  Future<void> submitOutcome(ReviewOutcome outcome) async {
    final currentMistake = state.currentMistake;
    if (currentMistake == null || state.isSubmitting) return;

    state = state.copyWith(isSubmitting: true);

    final now = DateTime.now();
    final nextReviewAt = now.add(_reviewIntervalFor(
      currentMistake.reviewCount + 1,
      outcome,
    ));
    final updatedOutcomes = Map<int, ReviewOutcome>.from(state.outcomes)
      ..[currentMistake.id!] = outcome;

    await ref.read(mistakesProvider.notifier).updateMistakeReviewData(
          id: currentMistake.id!,
          reviewCount: currentMistake.reviewCount + 1,
          masteryLevel: _masteryLevelFor(outcome),
          lastReviewedAt: now,
          nextReviewAt: nextReviewAt,
          errorType: _errorTypeFor(outcome),
        );

    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      outcomes: updatedOutcomes,
      showAnswer: false,
      isSubmitting: false,
    );

    ref.invalidate(reviewSummaryProvider);
    ref.invalidate(reviewQueuesProvider);
  }

  int _masteryLevelFor(ReviewOutcome outcome) {
    switch (outcome) {
      case ReviewOutcome.mastered:
        return 2;
      case ReviewOutcome.almost:
        return 1;
      case ReviewOutcome.retry:
        return 0;
    }
  }

  String _errorTypeFor(ReviewOutcome outcome) {
    switch (outcome) {
      case ReviewOutcome.mastered:
        return '會了';
      case ReviewOutcome.almost:
        return '半懂';
      case ReviewOutcome.retry:
        return '需要重學';
    }
  }

  Duration _reviewIntervalFor(int reviewCount, ReviewOutcome outcome) {
    const dayPlan = [1, 3, 7, 14, 30];
    final safeIndex =
        math.min(math.max(reviewCount - 1, 0), dayPlan.length - 1);
    final baseDays = dayPlan[safeIndex];

    switch (outcome) {
      case ReviewOutcome.mastered:
        return Duration(days: baseDays);
      case ReviewOutcome.almost:
        return Duration(days: math.max(1, (baseDays / 2).round()));
      case ReviewOutcome.retry:
        return const Duration(days: 1);
    }
  }
}

final reviewSessionProvider =
    StateNotifierProvider<ReviewSessionController, ReviewSessionState>(
  (ref) => ReviewSessionController(ref),
);
