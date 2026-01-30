import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bubble_library/notifications/notification_service.dart';
import '../bubble_library/notifications/scheduled_push_cache.dart';
import '../notifications/push_exclusion_store.dart';
import '../notifications/daily_routine_store.dart';
import '../ui/rich_sections/user_state_store.dart';

/// 重置服务：清除所有用户数据，将 app 恢复到完全未使用的状态
class ResetService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  ResetService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in');
    return u.uid;
  }

  /// 完全重置：清除所有 Firestore 和本地数据
  /// 
  /// 包括：
  /// - Firestore: library_products, wishlist, saved_items, push_settings, 
  ///   topicProgress, contentState, progress
  /// - SharedPreferences: 所有本地存储的数据
  /// - 本地通知：取消所有已排程的通知
  Future<void> resetAll() async {
    if (kDebugMode) {
      debugPrint('🔄 开始重置所有数据...');
    }

    try {
      // 1. 清除 Firestore 数据
      await _clearFirestoreData();

      // 2. 清除本地 SharedPreferences
      await _clearLocalData();

      // 3. 取消所有本地通知
      await _clearNotifications();

      if (kDebugMode) {
        debugPrint('✅ 重置完成！app 已恢复到完全未使用的状态');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ 重置失败: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  /// 清除 Firestore 中的所有用户数据
  Future<void> _clearFirestoreData() async {
    if (kDebugMode) {
      debugPrint('🔥 正在清除 Firestore 数据...');
    }

    final uid = _uid;

    // 清除所有子集合
    final collections = [
      'library_products',
      'wishlist',
      'saved_items',
      'push_settings',
      'topicProgress',
      'contentState',
      'progress',
    ];

    // ✅ 并行读取所有集合（而不是串行）
    if (kDebugMode) {
      debugPrint('📖 并行读取 ${collections.length} 个集合...');
    }

    final snapshots = await Future.wait(
      collections.map((collectionName) => _db
          .collection('users')
          .doc(uid)
          .collection(collectionName)
          .get()),
    );

    if (kDebugMode) {
      final totalDocs = snapshots.fold<int>(0, (acc, s) => acc + s.docs.length);
      debugPrint('📊 共找到 $totalDocs 个文档需要删除');
    }

    // ✅ Firestore batch 有 500 个操作的限制，所以需要分批
    const batchSize = 450; // 留一些余量
    var currentBatch = _db.batch();
    var operationCount = 0;
    final batches = <WriteBatch>[currentBatch];

    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        currentBatch.delete(doc.reference);
        operationCount++;

        if (operationCount >= batchSize) {
          currentBatch = _db.batch();
          batches.add(currentBatch);
          operationCount = 0;
        }
      }
    }

    // ✅ 并行提交所有批次
    if (kDebugMode) {
      debugPrint('💾 提交 ${batches.length} 个批次...');
    }
    await Future.wait(batches.map((b) => b.commit()));

    if (kDebugMode) {
      debugPrint('✅ Firestore 数据已清除');
    }
  }

  /// 清除所有本地 SharedPreferences 数据
  Future<void> _clearLocalData() async {
    if (kDebugMode) {
      debugPrint('💾 正在清除本地数据...');
    }

    final sp = await SharedPreferences.getInstance();

    // 获取所有 key
    final allKeys = sp.getKeys();

    // 过滤出与当前用户相关的 key（包含 uid 或通用的 key）
    final keysToRemove = <String>[];

    for (final key in allKeys) {
      // 移除所有包含当前 uid 的 key
      if (key.contains(_uid)) {
        keysToRemove.add(key);
      }
      // 移除通用的 key（不包含 uid 的）
      else if (_isCommonKey(key)) {
        keysToRemove.add(key);
      }
    }

    if (kDebugMode) {
      debugPrint('🔑 找到 ${keysToRemove.length} 个本地 key 需要删除');
    }

    // ✅ 并行删除所有 key（而不是串行）
    await Future.wait(keysToRemove.map((key) => sp.remove(key)));

    // ✅ 并行清除所有通知相关的数据
    try {
      await Future.wait([
        PushExclusionStore.clearAll(_uid),
        ScheduledPushCache().clear(),
        DailyRoutineStore.clear(_uid),
        UserStateStore().clearRecentSearches(),
      ]);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ 清除部分本地数据时出错: $e');
      }
    }

    // 清除其他通过 SharedPreferences 存储的数据
    // SkipNextStore, FavoriteSentencesStore, MePrefsStore, UserLearningStore, WishlistStore 等
    // 这些会通过上面的 key 过滤逻辑自动清除

    if (kDebugMode) {
      debugPrint('✅ 本地数据已清除');
    }
  }

  /// 判断是否为通用的 key（不包含 uid）
  bool _isCommonKey(String key) {
    // 通用的 key 列表（根据 DATA_ARCHITECTURE.md）
    const commonKeys = [
      'recent_searches_v1',
      'last_view_topic_id_v1',
      'last_view_day_v1',
      'last_view_title_v1',
      'today_key_v1',
      'learned_today_v1',
      'app_theme_id',
      'scheduled_push_cache_v1',
      'local_action_queue_v1',
      'pending_dismiss_',
      'learned_v1:',
      'learned_global_v1:',
      'learn_days_',
      'wishlist_v2_',
      'favorite_sentences_',
      'me_interest_tags_',
      'me_custom_interest_tags_',
      'lb_coming_soon_remind_',
    ];

    return commonKeys.any((k) => key.startsWith(k) || key == k);
  }

  /// 取消所有本地通知
  Future<void> _clearNotifications() async {
    if (kDebugMode) {
      debugPrint('🔔 正在清除本地通知...');
    }

    try {
      final ns = NotificationService();
      await ns.cancelAll();
      final cache = ScheduledPushCache();
      await cache.clear();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ 清除通知时出错: $e');
      }
    }

    if (kDebugMode) {
      debugPrint('✅ 本地通知已清除');
    }
  }

  /// 仅清除本地数据（不清除 Firestore）
  Future<void> resetLocalOnly() async {
    if (kDebugMode) {
      debugPrint('🔄 开始重置本地数据（保留 Firestore）...');
    }

    try {
      await _clearLocalData();
      await _clearNotifications();

      if (kDebugMode) {
        debugPrint('✅ 本地数据重置完成');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ 重置失败: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }
}
