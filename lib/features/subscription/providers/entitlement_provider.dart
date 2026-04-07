import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/services/revenuecat_service.dart';
import '../../../core/services/subscription_backend_service.dart';
import '../../../core/utils/subscription_debug.dart';
import '../../auth/providers/auth_session_provider.dart';
import 'backend_subscription_provider.dart';
import 'subscription_ui_provider.dart';

const _defaultEntitlementId = 'premium';
const _backendVerificationMaxAge = Duration(minutes: 5);

enum EntitlementStatus {
  loading,
  expired,
  active,
  cancelled,
  billingIssue,
}

EntitlementStatus resolveEntitlementStatus({
  required bool hasAccess,
  required bool willRenew,
  required DateTime? unsubscribeDetectedAt,
  required DateTime? billingIssueDetectedAt,
}) {
  if (!hasAccess) {
    return EntitlementStatus.expired;
  }
  if (billingIssueDetectedAt != null) {
    return EntitlementStatus.billingIssue;
  }
  if (unsubscribeDetectedAt != null || !willRenew) {
    return EntitlementStatus.cancelled;
  }
  return EntitlementStatus.active;
}

EntitlementState resolveEffectiveEntitlementState({
  required EntitlementState baseState,
  required bool isLoggedIn,
  required bool backendSyncInFlight,
  required BackendSubscriptionStatus? backendStatus,
  required String? backendLastError,
}) {
  if (!isLoggedIn) {
    return baseState.copyWith(
      isBackendVerified: false,
      backendLastSyncedAt: backendStatus?.updatedAt,
      backendLastError: backendLastError,
      localHasAccess: baseState.hasAccess,
      pendingChanges: backendStatus?.pendingChanges ?? baseState.pendingChanges,
    );
  }

  if (backendStatus != null) {
    final backendResolvedStatus = resolveEntitlementStatus(
      hasAccess: backendStatus.hasAccess,
      willRenew: backendStatus.willRenew,
      unsubscribeDetectedAt: backendStatus.unsubscribeDetectedAt,
      billingIssueDetectedAt: backendStatus.billingIssueDetectedAt,
    );
    final effectiveCurrentProductId = backendStatus.hasAccess
        ? (backendStatus.currentProductId ?? baseState.currentProductId)
        : null;
    final effectiveCurrentPlanId = backendStatus.hasAccess
        ? (backendStatus.currentPlanId ?? baseState.currentPlanId)
        : null;
    final effectivePendingChanges = backendStatus.hasAccess
        ? backendStatus.pendingChanges
        : const <PendingSubscriptionChange>[];
    return baseState.copyWith(
      status: backendResolvedStatus,
      hasAccess: backendStatus.hasAccess,
      currentProductId: effectiveCurrentProductId,
      currentPlanId: effectiveCurrentPlanId,
      expirationDate: backendStatus.expirationDate ?? baseState.expirationDate,
      latestPurchaseDate:
          backendStatus.latestPurchaseDate ?? baseState.latestPurchaseDate,
      unsubscribeDetectedAt: backendStatus.unsubscribeDetectedAt,
      billingIssueDetectedAt: backendStatus.billingIssueDetectedAt,
      willRenew: backendStatus.willRenew,
      pendingChanges: effectivePendingChanges,
      isBackendVerified: true,
      backendLastSyncedAt: backendStatus.updatedAt,
      backendLastError: backendLastError,
      isLoading: baseState.isLoading || backendSyncInFlight,
      localHasAccess: baseState.hasAccess,
      clearCurrentProductId: !backendStatus.hasAccess,
      clearCurrentPlanId: !backendStatus.hasAccess,
      clearUnsubscribeDetectedAt: backendStatus.unsubscribeDetectedAt == null,
      clearBillingIssueDetectedAt: backendStatus.billingIssueDetectedAt == null,
    );
  }

  if (backendSyncInFlight) {
    if (baseState.hasAccess) {
      return baseState.copyWith(
        isLoading: true,
        isBackendVerified: false,
        backendLastError: backendLastError,
        localHasAccess: baseState.hasAccess,
        pendingChanges: backendStatus?.pendingChanges ?? baseState.pendingChanges,
      );
    }
    return baseState.copyWith(
      status: EntitlementStatus.loading,
      hasAccess: false,
      isLoading: true,
      currentProductId: null,
      currentPlanId: null,
      isBackendVerified: false,
      backendLastError: backendLastError,
      localHasAccess: baseState.hasAccess,
      pendingChanges: const <PendingSubscriptionChange>[],
      clearCurrentProductId: true,
      clearCurrentPlanId: true,
    );
  }

  if (baseState.hasAccess) {
    return baseState.copyWith(
      isLoading: false,
      isBackendVerified: false,
      backendLastError: backendLastError,
      localHasAccess: baseState.hasAccess,
      pendingChanges: backendStatus?.pendingChanges ?? baseState.pendingChanges,
    );
  }

  return baseState.copyWith(
    status: backendLastError == null
        ? EntitlementStatus.loading
        : EntitlementStatus.expired,
    hasAccess: false,
    isLoading: false,
    currentProductId: null,
    currentPlanId: null,
    isBackendVerified: false,
    backendLastError: backendLastError,
    localHasAccess: baseState.hasAccess,
    pendingChanges: const <PendingSubscriptionChange>[],
    clearCurrentProductId: true,
    clearCurrentPlanId: true,
  );
}

class EntitlementState {
  const EntitlementState({
    required this.status,
    required this.hasAccess,
    required this.isLoading,
    this.currentProductId,
    this.currentPlanId,
    this.pendingChanges = const [],
    this.managementUrl,
    this.store,
    this.periodType,
    this.expirationDate,
    this.latestPurchaseDate,
    this.originalPurchaseDate,
    this.unsubscribeDetectedAt,
    this.billingIssueDetectedAt,
    this.originalAppUserId,
    this.currentAppUserId,
    this.willRenew = false,
    this.isSandbox = false,
    this.lastError,
    this.isBackendVerified = false,
    this.backendLastSyncedAt,
    this.backendLastError,
    this.localHasAccess = false,
  });

  final EntitlementStatus status;
  final bool hasAccess;
  final bool isLoading;
  final String? currentProductId;
  final String? currentPlanId;
  final List<PendingSubscriptionChange> pendingChanges;
  final String? managementUrl;
  final Store? store;
  final PeriodType? periodType;
  final DateTime? expirationDate;
  final DateTime? latestPurchaseDate;
  final DateTime? originalPurchaseDate;
  final DateTime? unsubscribeDetectedAt;
  final DateTime? billingIssueDetectedAt;
  final String? originalAppUserId;
  final String? currentAppUserId;
  final bool willRenew;
  final bool isSandbox;
  final String? lastError;
  final bool isBackendVerified;
  final DateTime? backendLastSyncedAt;
  final String? backendLastError;
  final bool localHasAccess;

  const EntitlementState.initial()
      : status = EntitlementStatus.loading,
        hasAccess = false,
        isLoading = true,
        currentProductId = null,
        currentPlanId = null,
        pendingChanges = const [],
        managementUrl = null,
        store = null,
        periodType = null,
        expirationDate = null,
        latestPurchaseDate = null,
        originalPurchaseDate = null,
        unsubscribeDetectedAt = null,
        billingIssueDetectedAt = null,
        originalAppUserId = null,
        currentAppUserId = null,
        willRenew = false,
        isSandbox = false,
        lastError = null,
        isBackendVerified = false,
        backendLastSyncedAt = null,
        backendLastError = null,
        localHasAccess = false;

  EntitlementState copyWith({
    EntitlementStatus? status,
    bool? hasAccess,
    bool? isLoading,
    String? currentProductId,
    String? currentPlanId,
    List<PendingSubscriptionChange>? pendingChanges,
    String? managementUrl,
    Store? store,
    PeriodType? periodType,
    DateTime? expirationDate,
    DateTime? latestPurchaseDate,
    DateTime? originalPurchaseDate,
    DateTime? unsubscribeDetectedAt,
    DateTime? billingIssueDetectedAt,
    String? originalAppUserId,
    String? currentAppUserId,
    bool? willRenew,
    bool? isSandbox,
    String? lastError,
    bool? isBackendVerified,
    DateTime? backendLastSyncedAt,
    String? backendLastError,
    bool? localHasAccess,
    bool clearCurrentProductId = false,
    bool clearCurrentPlanId = false,
    bool clearUnsubscribeDetectedAt = false,
    bool clearBillingIssueDetectedAt = false,
    bool clearError = false,
  }) {
    return EntitlementState(
      status: status ?? this.status,
      hasAccess: hasAccess ?? this.hasAccess,
      isLoading: isLoading ?? this.isLoading,
      currentProductId: clearCurrentProductId
          ? null
          : (currentProductId ?? this.currentProductId),
      currentPlanId:
          clearCurrentPlanId ? null : (currentPlanId ?? this.currentPlanId),
      pendingChanges: pendingChanges ?? this.pendingChanges,
      managementUrl: managementUrl ?? this.managementUrl,
      store: store ?? this.store,
      periodType: periodType ?? this.periodType,
      expirationDate: expirationDate ?? this.expirationDate,
      latestPurchaseDate: latestPurchaseDate ?? this.latestPurchaseDate,
      originalPurchaseDate: originalPurchaseDate ?? this.originalPurchaseDate,
      unsubscribeDetectedAt: clearUnsubscribeDetectedAt
          ? null
          : (unsubscribeDetectedAt ?? this.unsubscribeDetectedAt),
      billingIssueDetectedAt: clearBillingIssueDetectedAt
          ? null
          : (billingIssueDetectedAt ?? this.billingIssueDetectedAt),
      originalAppUserId: originalAppUserId ?? this.originalAppUserId,
      currentAppUserId: currentAppUserId ?? this.currentAppUserId,
      willRenew: willRenew ?? this.willRenew,
      isSandbox: isSandbox ?? this.isSandbox,
      lastError: clearError ? null : (lastError ?? this.lastError),
      isBackendVerified: isBackendVerified ?? this.isBackendVerified,
      backendLastSyncedAt: backendLastSyncedAt ?? this.backendLastSyncedAt,
      backendLastError: backendLastError ?? this.backendLastError,
      localHasAccess: localHasAccess ?? this.localHasAccess,
    );
  }

  bool get isSubscribed => hasAccess;

  bool get isCancelledButActive => hasAccess && !willRenew;

  bool get isInGracePeriod => hasAccess && billingIssueDetectedAt != null;

  bool get canSwitchPlan => hasAccess && currentPlanId != null;

  String get statusLabel => switch (status) {
        EntitlementStatus.loading => '正在同步訂閱狀態',
        EntitlementStatus.expired => '目前未訂閱',
        EntitlementStatus.active => '訂閱有效，將自動續訂',
        EntitlementStatus.cancelled => '已取消續訂，權限仍有效',
        EntitlementStatus.billingIssue => '付款異常，請更新付款方式',
      };

  String get renewalDescription {
    final dateLabel = _formatDate(expirationDate);
    return switch (status) {
      EntitlementStatus.loading => '正在讀取商店資料',
      EntitlementStatus.expired => '目前沒有有效訂閱',
      EntitlementStatus.active =>
        dateLabel == null ? '訂閱目前有效' : '下次續訂日：$dateLabel',
      EntitlementStatus.cancelled =>
        dateLabel == null ? '已取消續訂' : '權限將於 $dateLabel 到期',
      EntitlementStatus.billingIssue =>
        dateLabel == null ? '付款異常，但目前可能仍在寬限期' : '付款異常，若未修復將於 $dateLabel 失效',
    };
  }
}

final entitlementProvider =
    StateNotifierProvider<EntitlementNotifier, EntitlementState>(
  (ref) => EntitlementNotifier(ref),
);

class EntitlementNotifier extends StateNotifier<EntitlementState> {
  EntitlementNotifier(this._ref) : super(const EntitlementState.initial()) {
    Purchases.addCustomerInfoUpdateListener(_customerInfoListener);
    _ref.listen<AuthSessionState>(
      authSessionProvider,
      (previous, next) {
        if (previous?.uid == next.uid) {
          return;
        }
        _log(
          'authChanged prevUid=${previous?.uid ?? "null"} '
          'nextUid=${next.uid ?? "null"}',
        );
        _backendStatus = null;
        _backendLastError = null;
        _backendLastCheckAt = null;
        _baseState = const EntitlementState.initial();
        _recomputeState();
        if (next.uid != null && next.uid!.isNotEmpty) {
          unawaited(_syncBackendStatus());
        }
      },
      fireImmediately: true,
    );
    _ref.listen<AsyncValue<BackendSubscriptionStatus?>>(
      backendSubscriptionStatusProvider,
      (_, next) {
        next.when(
          data: (value) {
            _backendStatus = value;
            _log(
              'backendStream:data hasStatus=${value != null} '
              'hasAccess=${value?.hasAccess ?? false} '
              'planId=${value?.currentPlanId ?? "null"}',
            );
            _recomputeState();
          },
          loading: () {
            _log('backendStream:loading');
            _recomputeState();
          },
          error: (error, _) {
            _backendLastError = '$error';
            _log('backendStream:error error=$error');
            _recomputeState();
          },
        );
      },
      fireImmediately: true,
    );
    refreshEntitlement();
  }

  final Ref _ref;
  final RevenueCatService _revenueCatService = RevenueCatService.instance;
  EntitlementState _baseState = const EntitlementState.initial();
  BackendSubscriptionStatus? _backendStatus;
  String? _backendLastError;
  bool _backendSyncInFlight = false;
  Future<void>? _backendSyncFuture;
  DateTime? _backendLastCheckAt;

  void _log(String message) => subscriptionDebugLog('Entitlement', message);

  void _customerInfoListener(CustomerInfo customerInfo) {
    _log(
      'customerInfoListener:activeEntitlements='
      '${customerInfo.entitlements.active.keys.join(",")}',
    );
    _applyCustomerInfo(customerInfo);
  }

  Future<void> refreshEntitlement() async {
    final stopwatch = Stopwatch()..start();
    _log('refreshEntitlement:start');
    _baseState = _baseState.copyWith(isLoading: true, clearError: true);
    _recomputeState();
    try {
      final customerInfo = await _revenueCatService.getCustomerInfo(
        invalidateCache: true,
      );
      _applyCustomerInfo(customerInfo);
      _log(
        'refreshEntitlement:customerInfoApplied '
        'elapsedMs=${stopwatch.elapsedMilliseconds} '
        'localHasAccess=${_baseState.hasAccess} '
        'currentPlanId=${_baseState.currentPlanId ?? "null"}',
      );
    } catch (e) {
      _baseState = _baseState.copyWith(
        status: EntitlementStatus.expired,
        hasAccess: false,
        isLoading: false,
        lastError: '$e',
      );
      _log('refreshEntitlement:error elapsedMs=${stopwatch.elapsedMilliseconds} error=$e');
      _recomputeState();
    }
    await _syncBackendStatus();
    _log(
      'refreshEntitlement:done elapsedMs=${stopwatch.elapsedMilliseconds} '
      'status=${state.status.name} hasAccess=${state.hasAccess} '
      'localHasAccess=${state.localHasAccess} backendVerified=${state.isBackendVerified}',
    );
  }

  Future<void> _syncBackendStatus() {
    _backendSyncFuture ??= _syncBackendStatusInternal();
    return _backendSyncFuture!;
  }

  Future<void> _syncBackendStatusInternal() async {
    final stopwatch = Stopwatch()..start();
    final uid = _ref.read(authSessionProvider).uid;
    if (uid == null || uid.isEmpty) {
      _log('syncBackendStatus:skip missing_uid');
      return;
    }
    _backendSyncInFlight = true;
    _log('syncBackendStatus:start uid=$uid');
    _recomputeState();
    try {
      _backendLastError = null;
      _backendStatus = await _ref.read(backendSubscriptionSyncProvider)();
      _log(
        'syncBackendStatus:success elapsedMs=${stopwatch.elapsedMilliseconds} '
        'uid=$uid hasAccess=${_backendStatus?.hasAccess ?? false} '
        'planId=${_backendStatus?.currentPlanId ?? "null"}',
      );
      _recomputeState();
    } catch (e) {
      _backendLastError = '$e';
      _log(
        'syncBackendStatus:error elapsedMs=${stopwatch.elapsedMilliseconds} '
        'uid=$uid error=$e',
      );
    } finally {
      _backendSyncInFlight = false;
      _backendLastCheckAt = DateTime.now();
      _recomputeState();
      _backendSyncFuture = null;
    }
  }

  void _recomputeState() {
    state = resolveEffectiveEntitlementState(
      baseState: _baseState,
      isLoggedIn: _ref.read(authSessionProvider).isLoggedIn,
      backendSyncInFlight: _backendSyncInFlight,
      backendStatus: _backendStatus,
      backendLastError: _backendLastError,
    );
  }

  Future<void> refreshBackendVerification() async {
    await _syncBackendStatus();
    if (_backendStatus == null) {
      _recomputeState();
    }
  }

  Future<void> ensureFreshBackendVerification({
    Duration maxAge = _backendVerificationMaxAge,
    bool force = false,
  }) async {
    final uid = _ref.read(authSessionProvider).uid;
    if (uid == null || uid.isEmpty) {
      _log('ensureFreshBackendVerification:skip missing_uid');
      return;
    }
    if (!force) {
      final lastCheckedAt = _backendLastCheckAt;
      final isFresh = lastCheckedAt != null &&
          DateTime.now().difference(lastCheckedAt) <= maxAge;
      if (isFresh) {
        _log(
          'ensureFreshBackendVerification:skip fresh uid=$uid '
          'lastCheckedAt=$lastCheckedAt',
        );
        return;
      }
    }
    _log('ensureFreshBackendVerification:run uid=$uid force=$force');
    await _syncBackendStatus();
  }

  Future<void> purchaseByPlanId(String planId) async {
    _log('purchaseByPlanId:start planId=$planId');
    final offerings = await _revenueCatService.getOfferings();
    final current = offerings.current;
    if (current == null) {
      throw StateError('尚未設定可用方案（Offering current 為空）');
    }

    final packageId = subscriptionPlanById(planId).packageId;
    Package? target;
    for (final pkg in current.availablePackages) {
      if (pkg.identifier == packageId) {
        target = pkg;
        break;
      }
    }
    if (target == null) {
      throw StateError('找不到方案：$packageId');
    }

    await _revenueCatService.purchasePackage(target);
    await refreshEntitlement();
    if (!state.isBackendVerified && !state.localHasAccess) {
      _log('purchaseByPlanId:backend_unverified_without_local_access planId=$planId');
      throw StateError('後端尚未完成訂閱驗證，請稍後重新整理再試');
    }
    if (!state.hasAccess && !state.localHasAccess) {
      _log('purchaseByPlanId:no_access_after_purchase planId=$planId');
      throw StateError('後端尚未確認訂閱生效，請稍後重新整理或使用恢復購買');
    }
    _log(
      'purchaseByPlanId:success planId=$planId hasAccess=${state.hasAccess} '
      'localHasAccess=${state.localHasAccess} backendVerified=${state.isBackendVerified}',
    );
  }

  Future<void> restorePurchases() async {
    _log('restorePurchases:start');
    await _revenueCatService.restorePurchases();
    await refreshEntitlement();
    if (!state.isBackendVerified && !state.localHasAccess) {
      _log('restorePurchases:backend_unverified_without_local_access');
      throw StateError('後端尚未完成恢復驗證，請稍後重新整理再試');
    }
    _log(
      'restorePurchases:success hasAccess=${state.hasAccess} '
      'localHasAccess=${state.localHasAccess} backendVerified=${state.isBackendVerified}',
    );
  }

  void _applyCustomerInfo(CustomerInfo customerInfo) {
    final entitlement = customerInfo.entitlements.all[_entitlementId] ??
        customerInfo.entitlements.active[_entitlementId];
    final hasPremium =
        customerInfo.entitlements.active[_entitlementId]?.isActive ?? false;
    final currentPlan =
        subscriptionPlanByProductId(entitlement?.productIdentifier);
    final unsubscribeDetectedAt =
        _parseRevenueCatDate(entitlement?.unsubscribeDetectedAt);
    final billingIssueDetectedAt =
        _parseRevenueCatDate(entitlement?.billingIssueDetectedAt);
    final nextStatus = resolveEntitlementStatus(
      hasAccess: hasPremium,
      willRenew: entitlement?.willRenew ?? false,
      unsubscribeDetectedAt: unsubscribeDetectedAt,
      billingIssueDetectedAt: billingIssueDetectedAt,
    );

    _baseState = EntitlementState(
      status: nextStatus,
      hasAccess: hasPremium,
      isLoading: false,
      currentProductId: entitlement?.productIdentifier,
      currentPlanId: currentPlan?.id,
      pendingChanges: state.pendingChanges,
      managementUrl: customerInfo.managementURL,
      store: entitlement?.store,
      periodType: entitlement?.periodType,
      expirationDate: _parseRevenueCatDate(
        entitlement?.expirationDate ?? customerInfo.latestExpirationDate,
      ),
      latestPurchaseDate: _parseRevenueCatDate(entitlement?.latestPurchaseDate),
      originalPurchaseDate:
          _parseRevenueCatDate(entitlement?.originalPurchaseDate),
      unsubscribeDetectedAt: unsubscribeDetectedAt,
      billingIssueDetectedAt: billingIssueDetectedAt,
      originalAppUserId: customerInfo.originalAppUserId,
      currentAppUserId: _revenueCatService.lastKnownAppUserId ??
          customerInfo.originalAppUserId,
      willRenew: entitlement?.willRenew ?? false,
      isSandbox: entitlement?.isSandbox ?? false,
    );
    _log(
      '_applyCustomerInfo hasPremium=$hasPremium '
      'planId=${currentPlan?.id ?? "null"} '
      'productId=${entitlement?.productIdentifier ?? "null"} '
      'currentAppUserId=${_baseState.currentAppUserId ?? "null"} '
      'originalAppUserId=${customerInfo.originalAppUserId}',
    );
    _recomputeState();
  }

  @override
  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_customerInfoListener);
    super.dispose();
  }

  String get _entitlementId {
    final fromEnv = AppEnvironment.revenuecatEntitlementId;
    return fromEnv.isNotEmpty ? fromEnv : _defaultEntitlementId;
  }
}

DateTime? _parseRevenueCatDate(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw)?.toLocal();
}

String? _formatDate(DateTime? value) {
  if (value == null) {
    return null;
  }

  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}/$month/$day';
}
