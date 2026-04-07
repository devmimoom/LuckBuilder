import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/providers/auth_session_provider.dart';

const _prefsKeyPrefix = 'home_tasks_learning_curve_tip_dismissed';

class LearningCurveTipState {
  const LearningCurveTipState({
    required this.isDismissedForever,
    required this.uidKey,
  });

  final bool isDismissedForever;
  final String uidKey;

  LearningCurveTipState copyWith({
    bool? isDismissedForever,
    String? uidKey,
  }) {
    return LearningCurveTipState(
      isDismissedForever: isDismissedForever ?? this.isDismissedForever,
      uidKey: uidKey ?? this.uidKey,
    );
  }

  static const initial = LearningCurveTipState(
    isDismissedForever: false,
    uidKey: 'anon',
  );
}

final learningCurveTipProvider =
    StateNotifierProvider<LearningCurveTipNotifier, LearningCurveTipState>(
  (ref) => LearningCurveTipNotifier(ref),
);

class LearningCurveTipNotifier extends StateNotifier<LearningCurveTipState> {
  LearningCurveTipNotifier(this._ref) : super(LearningCurveTipState.initial) {
    _ref.listen<AuthSessionState>(
      authSessionProvider,
      (prev, next) {
        final prevUidKey = _uidKeyFor(prev);
        final nextUidKey = _uidKeyFor(next);
        final loggedInChanged = (prev?.isLoggedIn ?? false) != next.isLoggedIn;
        final userChanged = prevUidKey != nextUidKey;
        if (loggedInChanged || userChanged) {
          unawaited(_syncForUser(nextUidKey));
        }
      },
      fireImmediately: true,
    );
  }

  final Ref _ref;

  String _uidKeyFor(AuthSessionState? auth) =>
      auth?.uid?.trim().isNotEmpty == true ? auth!.uid!.trim() : 'anon';

  String _prefsKeyForUidKey(String uidKey) => '$_prefsKeyPrefix:$uidKey';

  Future<void> _syncForUser(String uidKey) async {
    var dismissedForever = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      dismissedForever = prefs.getBool(_prefsKeyForUidKey(uidKey)) ?? false;
    } catch (_) {
      dismissedForever = false;
    }

    state = state.copyWith(
      uidKey: uidKey,
      isDismissedForever: dismissedForever,
    );
  }

  Future<void> dismissForever() async {
    if (state.isDismissedForever) return;
    state = state.copyWith(isDismissedForever: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyForUidKey(state.uidKey), true);
    } catch (_) {
      // Keep in-memory dismissal even if persistence fails.
    }
  }
}
