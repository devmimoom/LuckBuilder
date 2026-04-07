import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/trial_backend_service.dart';
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
    _ref.listen<AuthSessionState>(authSessionProvider, (previous, next) {
      // 只在 uid 變化時重新載入，避免其他 auth 狀態波動覆蓋最新扣點結果。
      if (previous?.uid == next.uid) {
        return;
      }
      unawaited(_bindToAuth(next.uid));
    });
    unawaited(_bindToAuth(_ref.read(authSessionProvider).uid));
  }

  final Ref _ref;
  StreamSubscription<BackendTrialStatus?>? _trialSub;

  Future<void> _bindToAuth(String? uid) async {
    await _trialSub?.cancel();
    if (uid == null || uid.isEmpty) {
      state = FeatureTrialState.initial().copyWith(isLoaded: true);
      return;
    }

    state = state.copyWith(isLoaded: false);
    _trialSub = TrialBackendService.instance.watchStatus(uid).listen((status) {
      if (status == null) {
        return;
      }
      _applyBackendStatus(status);
    });

    try {
      final status = await TrialBackendService.instance.ensureTrialStatus();
      _applyBackendStatus(status);
    } catch (_) {
      state = state.copyWith(isLoaded: true);
    }
  }

  Future<int> remainingOf(TrialFeature feature) async {
    if (!state.isLoaded) {
      await _bindToAuth(_ref.read(authSessionProvider).uid);
    }
    return state.remainingOf(feature);
  }

  Future<bool> canUse(TrialFeature feature) async {
    return (await remainingOf(feature)) > 0;
  }

  Future<bool> consume(TrialFeature feature) async {
    final uid = _ref.read(authSessionProvider).uid;
    if (uid == null || uid.isEmpty) {
      return false;
    }
    final remaining = await remainingOf(feature);
    if (remaining <= 0) {
      return false;
    }
    final status = await TrialBackendService.instance.consumeTrialQuota(
      feature.backendKey,
    );
    _applyBackendStatus(status);
    return state.remainingOf(feature) < remaining;
  }

  void _applyBackendStatus(BackendTrialStatus status) {
    state = FeatureTrialState(
      remainingByFeature: {
        TrialFeature.cameraSolve: status.cameraSolveRemaining,
        TrialFeature.similarPractice: status.similarPracticeRemaining,
        TrialFeature.bannerPromotion: status.bannerPromotionRemaining,
      },
      isLoaded: true,
    );
  }

  @override
  void dispose() {
    _trialSub?.cancel();
    super.dispose();
  }
}

extension on TrialFeature {
  String get backendKey => switch (this) {
        TrialFeature.cameraSolve => 'cameraSolve',
        TrialFeature.similarPractice => 'similarPractice',
        TrialFeature.bannerPromotion => 'bannerPromotion',
      };
}
