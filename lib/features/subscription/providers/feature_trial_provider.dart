import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/providers/auth_session_provider.dart';

enum TrialFeature {
  cameraSolve,
  similarPractice,
  bannerPromotion,
}

extension TrialFeatureX on TrialFeature {
  String get basePrefsKey => switch (this) {
        TrialFeature.cameraSolve => 'trial_remaining_camera_solve',
        TrialFeature.similarPractice => 'trial_remaining_similar_practice',
        TrialFeature.bannerPromotion => 'trial_remaining_banner_promotion',
      };

  String get label => switch (this) {
        TrialFeature.cameraSolve => 'AI 拍照解題',
        TrialFeature.similarPractice => 'AI 相似題練習',
        TrialFeature.bannerPromotion => '學習橫幅推播',
      };

  int get initialQuota => 3;
}

class FeatureTrialState {
  const FeatureTrialState({
    required this.remainingByFeature,
    this.isLoaded = false,
  });

  final Map<TrialFeature, int> remainingByFeature;
  final bool isLoaded;

  factory FeatureTrialState.initial() => FeatureTrialState(
        remainingByFeature: {
          for (final feature in TrialFeature.values) feature: feature.initialQuota,
        },
      );

  int remainingOf(TrialFeature feature) =>
      remainingByFeature[feature] ?? feature.initialQuota;

  FeatureTrialState copyWith({
    Map<TrialFeature, int>? remainingByFeature,
    bool? isLoaded,
  }) {
    return FeatureTrialState(
      remainingByFeature: remainingByFeature ?? this.remainingByFeature,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

final featureTrialProvider =
    StateNotifierProvider<FeatureTrialNotifier, FeatureTrialState>(
  (ref) => FeatureTrialNotifier(ref),
);

class FeatureTrialNotifier extends StateNotifier<FeatureTrialState> {
  FeatureTrialNotifier(this._ref) : super(FeatureTrialState.initial()) {
    _ref.listen<AuthSessionState>(authSessionProvider, (_, __) {
      _load();
    });
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final values = {
        for (final feature in TrialFeature.values)
          feature:
              prefs.getInt(_prefsKeyFor(feature)) ?? feature.initialQuota,
      };
      state = FeatureTrialState(
        remainingByFeature: values,
        isLoaded: true,
      );
    } catch (_) {
      state = state.copyWith(isLoaded: true);
    }
  }

  Future<int> remainingOf(TrialFeature feature) async {
    if (!state.isLoaded) {
      await _load();
    }
    return state.remainingOf(feature);
  }

  Future<bool> canUse(TrialFeature feature) async {
    return (await remainingOf(feature)) > 0;
  }

  Future<bool> consume(TrialFeature feature) async {
    final remaining = await remainingOf(feature);
    if (remaining <= 0) return false;

    final next = remaining - 1;
    final updated = Map<TrialFeature, int>.from(state.remainingByFeature)
      ..[feature] = next;
    state = state.copyWith(remainingByFeature: updated, isLoaded: true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeyFor(feature), next);
    } catch (_) {
      // Keep in-memory state even if persistence fails.
    }
    return true;
  }

  String _prefsKeyFor(TrialFeature feature) {
    final uid = _ref.read(authSessionProvider).uid;
    final scope = (uid == null || uid.isEmpty) ? 'guest' : uid;
    return '${feature.basePrefsKey}_$scope';
  }
}
