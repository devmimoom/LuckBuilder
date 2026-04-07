import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/subscription_backend_service.dart';
import '../../auth/providers/auth_session_provider.dart';

final backendSubscriptionStatusProvider =
    StreamProvider<BackendSubscriptionStatus?>((ref) {
  final uid = ref.watch(authSessionProvider).uid;
  if (uid == null || uid.isEmpty) {
    return Stream<BackendSubscriptionStatus?>.value(null);
  }
  return SubscriptionBackendService.instance.watchStatus(uid);
});

final backendSubscriptionSyncProvider =
    Provider<Future<BackendSubscriptionStatus> Function()>((ref) {
  return () async {
    final authState = ref.read(authSessionProvider);
    final uid = authState.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('尚未登入，無法同步後端訂閱狀態');
    }
    return SubscriptionBackendService.instance.syncCurrentUserStatus();
  };
});
