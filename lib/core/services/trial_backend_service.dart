import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class BackendTrialStatus {
  const BackendTrialStatus({
    required this.cameraSolveRemaining,
    required this.similarPracticeRemaining,
    required this.bannerPromotionRemaining,
    this.updatedAt,
  });

  final int cameraSolveRemaining;
  final int similarPracticeRemaining;
  final int bannerPromotionRemaining;
  final DateTime? updatedAt;

  factory BackendTrialStatus.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return BackendTrialStatus(
      cameraSolveRemaining: _toInt(data['cameraSolveRemaining'], fallback: 3),
      similarPracticeRemaining:
          _toInt(data['similarPracticeRemaining'], fallback: 3),
      bannerPromotionRemaining:
          _toInt(data['bannerPromotionRemaining'], fallback: 3),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  factory BackendTrialStatus.fromCallableData(Map<Object?, Object?> data) {
    return BackendTrialStatus(
      cameraSolveRemaining: _toInt(data['cameraSolveRemaining'], fallback: 3),
      similarPracticeRemaining:
          _toInt(data['similarPracticeRemaining'], fallback: 3),
      bannerPromotionRemaining:
          _toInt(data['bannerPromotionRemaining'], fallback: 3),
      updatedAt: _toDateTimeFromMillis(data['updatedAtMs']),
    );
  }

  static int _toInt(Object? value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    return fallback;
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }
    return null;
  }

  static DateTime? _toDateTimeFromMillis(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    }
    return null;
  }
}

class TrialBackendService {
  TrialBackendService._();

  static final TrialBackendService instance = TrialBackendService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-east1');

  Stream<BackendTrialStatus?> watchStatus(String uid) {
    return _firestore
        .collection('feature_trial_status')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return BackendTrialStatus.fromFirestore(snapshot);
    });
  }

  Future<BackendTrialStatus> ensureTrialStatus() async {
    final callable = _functions.httpsCallable('getTrialStatus');
    final result = await callable.call<Map<Object?, Object?>>();
    final rawStatus = result.data['status'];
    if (rawStatus is! Map<Object?, Object?>) {
      throw StateError('後端未回傳有效的試用狀態');
    }
    return BackendTrialStatus.fromCallableData(rawStatus);
  }

  Future<BackendTrialStatus> consumeTrialQuota(String featureKey) async {
    final callable = _functions.httpsCallable('consumeTrialQuota');
    final result = await callable.call<Map<Object?, Object?>>({
      'feature': featureKey,
    });
    final rawStatus = result.data['status'];
    if (rawStatus is! Map<Object?, Object?>) {
      throw StateError('後端未回傳有效的試用狀態');
    }
    return BackendTrialStatus.fromCallableData(rawStatus);
  }
}
