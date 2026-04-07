import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../utils/subscription_debug.dart';

const _callableTimeout = Duration(seconds: 15);

class PendingSubscriptionChange {
  const PendingSubscriptionChange({
    required this.productId,
    required this.planId,
    this.eventId,
    this.requestedAt,
  });

  final String productId;
  final String? planId;
  final String? eventId;
  final DateTime? requestedAt;

  factory PendingSubscriptionChange.fromFirestore(
    Map<String, dynamic> data,
  ) {
    return PendingSubscriptionChange(
      productId: data['productId'] as String? ?? '',
      planId: data['planId'] as String?,
      eventId: data['eventId'] as String?,
      requestedAt: BackendSubscriptionStatus._toDateTime(data['requestedAt']),
    );
  }

  factory PendingSubscriptionChange.fromCallableData(
    Map<Object?, Object?> data,
  ) {
    return PendingSubscriptionChange(
      productId: data['productId'] as String? ?? '',
      planId: data['planId'] as String?,
      eventId: data['eventId'] as String?,
      requestedAt: BackendSubscriptionStatus._toDateTimeFromMillis(
          data['requestedAtMs']),
    );
  }
}

class BackendSubscriptionStatus {
  const BackendSubscriptionStatus({
    required this.hasAccess,
    required this.willRenew,
    this.currentProductId,
    this.currentPlanId,
    this.pendingChanges = const [],
    this.expirationDate,
    this.latestPurchaseDate,
    this.unsubscribeDetectedAt,
    this.billingIssueDetectedAt,
    this.updatedAt,
  });

  final bool hasAccess;
  final bool willRenew;
  final String? currentProductId;
  final String? currentPlanId;
  final List<PendingSubscriptionChange> pendingChanges;
  final DateTime? expirationDate;
  final DateTime? latestPurchaseDate;
  final DateTime? unsubscribeDetectedAt;
  final DateTime? billingIssueDetectedAt;
  final DateTime? updatedAt;

  factory BackendSubscriptionStatus.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return BackendSubscriptionStatus(
      hasAccess: data['entitlementActive'] == true,
      willRenew: data['willRenew'] == true,
      currentProductId: data['productId'] as String?,
      currentPlanId: data['planId'] as String?,
      pendingChanges: _toPendingChanges(data['pendingChanges']),
      expirationDate: _toDateTime(data['expirationAt']),
      latestPurchaseDate: _toDateTime(data['latestPurchaseAt']),
      unsubscribeDetectedAt: _toDateTime(data['unsubscribeDetectedAt']),
      billingIssueDetectedAt: _toDateTime(data['billingIssueDetectedAt']),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  factory BackendSubscriptionStatus.fromCallableData(
    Map<Object?, Object?> data,
  ) {
    return BackendSubscriptionStatus(
      hasAccess: data['entitlementActive'] == true,
      willRenew: data['willRenew'] == true,
      currentProductId: data['productId'] as String?,
      currentPlanId: data['planId'] as String?,
      pendingChanges: _toPendingChanges(data['pendingChanges']),
      expirationDate: _toDateTimeFromMillis(data['expirationAtMs']),
      latestPurchaseDate: _toDateTimeFromMillis(data['latestPurchaseAtMs']),
      unsubscribeDetectedAt:
          _toDateTimeFromMillis(data['unsubscribeDetectedAtMs']),
      billingIssueDetectedAt:
          _toDateTimeFromMillis(data['billingIssueDetectedAtMs']),
      updatedAt: _toDateTimeFromMillis(data['updatedAtMs']),
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }
    return null;
  }

  static List<PendingSubscriptionChange> _toPendingChanges(Object? value) {
    if (value is! List) {
      return const [];
    }
    final items = <PendingSubscriptionChange>[];
    for (final item in value) {
      if (item is Map<String, dynamic>) {
        final parsed = PendingSubscriptionChange.fromFirestore(item);
        if (parsed.productId.isNotEmpty) {
          items.add(parsed);
        }
        continue;
      }
      if (item is Map<Object?, Object?>) {
        final parsed = PendingSubscriptionChange.fromCallableData(item);
        if (parsed.productId.isNotEmpty) {
          items.add(parsed);
        }
      }
    }
    return List.unmodifiable(items);
  }

  static DateTime? _toDateTimeFromMillis(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    }
    return null;
  }
}

class SubscriptionBackendService {
  SubscriptionBackendService._();

  static final SubscriptionBackendService instance =
      SubscriptionBackendService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-east1');

  void _log(String message) => subscriptionDebugLog('Backend', message);

  Stream<BackendSubscriptionStatus?> watchStatus(String uid) {
    _log('watchStatus:subscribe uid=$uid');
    return _firestore
        .collection('subscription_status')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        _log('watchStatus:update uid=$uid exists=false');
        return null;
      }
      final status = BackendSubscriptionStatus.fromFirestore(snapshot);
      _log(
        'watchStatus:update uid=$uid exists=true hasAccess=${status.hasAccess} '
        'planId=${status.currentPlanId ?? "null"} updatedAt=${status.updatedAt}',
      );
      return status;
    });
  }

  Future<BackendSubscriptionStatus> syncCurrentUserStatus() async {
    final stopwatch = Stopwatch()..start();
    _log('syncCurrentUserStatus:start');
    final callable = _functions.httpsCallable(
      'syncSubscriptionStatus',
      options: HttpsCallableOptions(timeout: _callableTimeout),
    );
    try {
      final result = await callable.call<Map<Object?, Object?>>();
      final rawStatus = result.data['status'];
      if (rawStatus is! Map<Object?, Object?>) {
        throw StateError('後端未回傳有效的訂閱狀態');
      }
      final status = BackendSubscriptionStatus.fromCallableData(rawStatus);
      _log(
        'syncCurrentUserStatus:success elapsedMs=${stopwatch.elapsedMilliseconds} '
        'hasAccess=${status.hasAccess} planId=${status.currentPlanId ?? "null"} '
        'updatedAt=${status.updatedAt}',
      );
      return status;
    } catch (e) {
      _log(
        'syncCurrentUserStatus:error elapsedMs=${stopwatch.elapsedMilliseconds} '
        'error=$e',
      );
      rethrow;
    }
  }
}
