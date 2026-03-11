import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/learning_progress_service.dart';
import '../../services/shared_data_bridge.dart';
import '../../notifications/push_exclusion_store.dart';
import '../../widgets/rich_sections/user_learning_store.dart';
import 'notifications/notification_service.dart';
import 'notifications/notification_scheduler.dart';
import 'notifications/push_orchestrator.dart';
import 'notifications/timezone_init.dart';
import 'providers/providers.dart';
import '../../notifications/push_timeline_provider.dart';
import 'ui/detail_page.dart';
import 'ui/product_library_page.dart';
import 'ui/bubble_library_page.dart';
import '../../localization/app_language_provider.dart';
import '../../navigation/app_nav.dart';

class BubbleBootstrapper extends ConsumerStatefulWidget {
  final Widget child;
  const BubbleBootstrapper({super.key, required this.child});

  @override
  ConsumerState<BubbleBootstrapper> createState() => _BubbleBootstrapperState();
}

/// Deep link（onepop://open）檢查時機：
/// 1. 冷啟動：didChangeDependencies → addPostFrameCallback → 延遲 350ms → _checkPendingDeepLink
/// 2. 溫啟動：resumed → 延遲 350ms → _checkPendingDeepLink(recheckAfterEmpty: true)；若第一次取到空則 300ms 後再查一次
/// 3. App 已在前景：application:open:url 寫入後由 iOS 呼叫 checkPendingDeepLink → addPostFrameCallback → _checkPendingDeepLink
const _deepLinkChannel = MethodChannel('com.onepop.deeplink');

class _BubbleBootstrapperState extends ConsumerState<BubbleBootstrapper>
    with WidgetsBindingObserver {
  bool _inited = false;
  bool _isSyncingDone = false;
  final Set<String> _processedDoneItemIds = {};

  @override
  void initState() {
    super.initState();
    if (Platform.isIOS) {
      WidgetsBinding.instance.addObserver(this);
      // 讓 native 在 application:open:url 寫入 URL 後可通知 Flutter 檢查（App 已在前景時不會有 resumed）
      _deepLinkChannel.setMethodCallHandler(_onDeepLinkChannelCall);
    }
  }

  Future<dynamic> _onDeepLinkChannelCall(MethodCall call) async {
    if (call.method == 'checkPendingDeepLink') {
      if (kDebugMode) debugPrint('🔗 [DeepLink] native invoked checkPendingDeepLink');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _checkPendingDeepLink();
      });
    } else if (call.method == 'syncExtensionDone') {
      // Extension 按系統 action「Done」後由 AppDelegate didReceive 轉發到 Flutter
      final args = call.arguments as Map<dynamic, dynamic>?;
      final itemId = (args?['itemId'] as String?)?.trim() ?? '';
      if (kDebugMode) debugPrint('✅ [ExtDone] native invoked syncExtensionDone, itemId=$itemId');
      if (itemId.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          _handleExtensionDoneItem(itemId);
        });
      }
    }
    return null;
  }

  @override
  void dispose() {
    if (Platform.isIOS) {
      WidgetsBinding.instance.removeObserver(this);
      _deepLinkChannel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && Platform.isIOS) {
      if (kDebugMode) debugPrint('🔗 [DeepLink] resumed, scheduling _checkPendingDeepLink in 350ms');
      // 延遲再檢查，讓 iOS 有時間先執行 application:open:url 寫入 pending deep link（實測 150ms 仍常取到空）
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _checkPendingDeepLink(recheckAfterEmpty: true);
      });
      // 延遲同步 Extension Done，讓 UserDefaults 跨 process 有時間 synchronize
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _syncExtensionCompletedState();
      });
    }
  }

  /// Extension「Done」：透過 iOS action 轉發帶 itemId 過來，處理單一 item
  Future<void> _handleExtensionDoneItem(String itemId) async {
    if (!mounted) return;
    if (_processedDoneItemIds.contains(itemId)) {
      if (kDebugMode) debugPrint('✅ [ExtDone] itemId=$itemId already processed, skip');
      return;
    }
    _processedDoneItemIds.add(itemId);
    if (kDebugMode) debugPrint('✅ [ExtDone] _handleExtensionDoneItem start, itemId=$itemId');
    try {
      String uid;
      try {
        uid = ref.read(uidProvider);
      } catch (_) {
        return;
      }

      await PushExclusionStore.markOpened(uid, itemId);
      if (kDebugMode) debugPrint('✅ [ExtDone] markOpened done for $itemId');

      try {
        final libraryRepo = ref.read(libraryRepoProvider);
        await libraryRepo.setSavedItem(uid, itemId, {'learned': true});
        if (kDebugMode) debugPrint('✅ [ExtDone] setSavedItem learned=true for $itemId');
      } catch (e) {
        if (kDebugMode) debugPrint('❌ [ExtDone] setSavedItem error: $e');
      }

      try {
        final item = await ref.read(contentRepoProvider).getOne(itemId);
        if (kDebugMode) debugPrint('✅ [ExtDone] loaded contentItem product=${item.productId} pushOrder=${item.pushOrder}');
        final productsMap = await ref.read(productsMapProvider.future);
        final product = productsMap[item.productId];
        final topicId = product?.topicId;
        if (topicId != null && topicId.isNotEmpty) {
          final progress = ref.read(learningProgressServiceProvider);
          await progress.markLearnedAndAdvance(
            topicId: topicId,
            contentId: itemId,
            pushOrder: item.pushOrder,
            source: 'extension_done',
          );
          if (kDebugMode) debugPrint('✅ [ExtDone] markLearnedAndAdvance done');
        }
        await UserLearningStore().markLearnedTodayAndGlobal(item.productId);
        if (kDebugMode) debugPrint('✅ [ExtDone] markLearnedTodayAndGlobal done');
      } catch (e) {
        if (kDebugMode) debugPrint('❌ [ExtDone] progress error: $e');
      }

      try {
        await NotificationService().cancelByContentItemId(itemId);
        if (kDebugMode) debugPrint('✅ [ExtDone] cancelByContentItemId done');
      } catch (e) {
        if (kDebugMode) debugPrint('❌ [ExtDone] cancelByContentItemId error: $e');
      }

      if (!mounted) return;
      ref.invalidate(savedItemsProvider);
      ref.invalidate(libraryProductsProvider);
      ref.invalidate(scheduledCacheProvider);
      ref.invalidate(upcomingTimelineProvider);
      // Extension 按 Done 後，立刻重排未來 3 天（與 App 內 actionLearned 一致）
      try {
        final scheduler = ref.read(notificationSchedulerProvider);
        await scheduler.schedule(
          ref: ref,
          days: 3,
          source: 'extension_done',
          immediate: true,
        );
        if (kDebugMode) {
          debugPrint('✅ [ExtDone] rescheduleNextDays triggered (single item)');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ [ExtDone] rescheduleNextDays error (single item): $e');
        }
      }
      if (kDebugMode) debugPrint('✅ [ExtDone] _handleExtensionDoneItem done');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [ExtDone] _handleExtensionDoneItem error: $e');
    }
  }

  /// Extension「已讀完成」寫入 App Groups；resume 時同步到 App 內學習狀態（fallback 路徑）
  Future<void> _syncExtensionCompletedState() async {
    if (!mounted) return;
    if (_isSyncingDone) {
      if (kDebugMode) debugPrint('✅ [ExtDone] already syncing, skip');
      return;
    }
    _isSyncingDone = true;
    if (kDebugMode) debugPrint('✅ [ExtDone] _syncExtensionCompletedState start');
    try {
      String uid;
      try {
        uid = ref.read(uidProvider);
      } catch (_) {
        return;
      }

      final itemIds = await SharedDataBridge.getTodayCompleted();
      if (kDebugMode) {
        debugPrint('✅ [ExtDone] getTodayCompleted -> $itemIds');
        // 診斷：列出 App Group container 下的所有檔案與完成檔內容
        try {
          final diag = await SharedDataBridge.getDiagnosticInfo();
          debugPrint('✅ [ExtDone] diagnostic: $diag');
        } catch (_) {}
      }
      if (itemIds.isEmpty) return;

      final libraryRepo = ref.read(libraryRepoProvider);
      final progress = ref.read(learningProgressServiceProvider);
      final ns = NotificationService();

      for (final itemId in itemIds) {
        if (kDebugMode) debugPrint('✅ [ExtDone] handling itemId=$itemId');
        // 1) 標記通知已讀
        await PushExclusionStore.markOpened(uid, itemId);
        if (kDebugMode) debugPrint('✅ [ExtDone] markOpened done for $itemId');

        // 2) 標記 saved_items learned=true（讓 UI 顯示為已學習）
        try {
          await libraryRepo.setSavedItem(uid, itemId, {'learned': true});
          if (kDebugMode) debugPrint('✅ [ExtDone] setSavedItem learned=true for $itemId');
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('❌ [ExtDone] setSavedItem error for $itemId: $e');
            debugPrint('$st');
          }
        }

        // 3) 推進學習進度（需要 contentItem 的 productId / pushOrder / topicId）
        try {
          final item = await ref.read(contentRepoProvider).getOne(itemId);
          if (kDebugMode) {
            debugPrint(
              '✅ [ExtDone] loaded contentItem id=$itemId product=${item.productId} pushOrder=${item.pushOrder}',
            );
          }
          final productsMap = await ref.read(productsMapProvider.future);
          final product = productsMap[item.productId];
          final topicId = product?.topicId;
          if (topicId != null && topicId.isNotEmpty) {
            await progress.markLearnedAndAdvance(
              topicId: topicId,
              contentId: itemId,
              pushOrder: item.pushOrder,
              source: 'extension_done',
            );
            if (kDebugMode) {
              debugPrint(
                '✅ [ExtDone] markLearnedAndAdvance done topicId=$topicId product=${item.productId}',
              );
            }
          } else {
            if (kDebugMode) {
              debugPrint(
                '⚠️ [ExtDone] topicId is null/empty for product=${item.productId}',
              );
            }
          }
          await UserLearningStore().markLearnedTodayAndGlobal(item.productId);
          if (kDebugMode) {
            debugPrint('✅ [ExtDone] markLearnedTodayAndGlobal done product=${item.productId}');
          }
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('❌ [ExtDone] progress error for $itemId: $e');
            debugPrint('$st');
          }
        }

        // 4) 取消該則的已排程通知
        try {
          await ns.cancelByContentItemId(itemId);
          if (kDebugMode) {
            debugPrint('✅ [ExtDone] cancelByContentItemId done for $itemId');
          }
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('❌ [ExtDone] cancelByContentItemId error for $itemId: $e');
            debugPrint('$st');
          }
        }
      }

      await SharedDataBridge.clearTodayCompletedFile();
      await SharedDataBridge.cleanupOldData();
      if (kDebugMode) debugPrint('✅ [ExtDone] cleanupOldData done');
      if (!mounted) return;
      ref.invalidate(savedItemsProvider);
      ref.invalidate(libraryProductsProvider);
      ref.invalidate(scheduledCacheProvider);
      ref.invalidate(upcomingTimelineProvider);
      // 批次同步 Extension Done（冷啟動 / fallback）後，一次性重排未來 3 天
      try {
        final scheduler = ref.read(notificationSchedulerProvider);
        await scheduler.schedule(
          ref: ref,
          days: 3,
          source: 'extension_done_batch',
          immediate: true,
        );
        if (kDebugMode) {
          debugPrint('✅ [ExtDone] rescheduleNextDays triggered (batch)');
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('❌ [ExtDone] rescheduleNextDays error (batch): $e');
          debugPrint('$st');
        }
      }
      if (kDebugMode) debugPrint('✅ [ExtDone] _syncExtensionCompletedState done');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('❌ [ExtDone] _syncExtensionCompletedState error: $e');
        debugPrint('$st');
      }
    } finally {
      _isSyncingDone = false;
    }
  }

  Future<void> _checkPendingDeepLink({bool recheckAfterEmpty = false, int recheckAttempt = 0}) async {
    if (!mounted) return;
    if (kDebugMode) debugPrint('🔗 [DeepLink] _checkPendingDeepLink called (recheckAfterEmpty=$recheckAfterEmpty, recheckAttempt=$recheckAttempt)');
    try {
      final map = await _deepLinkChannel.invokeMapMethod<String, dynamic>('getPendingDeepLink');
      if (kDebugMode) debugPrint('🔗 [DeepLink] getPendingDeepLink result: $map');
      if (!mounted || map == null) return;
      final productId = (map['productId'] as String?)?.trim() ?? '';
      final contentItemId = (map['contentItemId'] as String?)?.trim() ?? '';
      final hasLink = contentItemId.isNotEmpty || productId.isNotEmpty;
      if (!hasLink) {
        if (kDebugMode) debugPrint('🔗 [DeepLink] hasLink=false, skipping');
        // 第一次為空時可能 iOS 尚未寫入，再排程檢查（最多再試 2 次：300ms、400ms）
        if (Platform.isIOS && (recheckAfterEmpty || recheckAttempt > 0) && recheckAttempt < 2) {
          final delayMs = recheckAttempt == 0 ? 300 : 400;
          if (kDebugMode) debugPrint('🔗 [DeepLink] scheduling check #${recheckAttempt + 2} in ${delayMs}ms');
          Future.delayed(Duration(milliseconds: delayMs), () {
            if (!mounted) return;
            _checkPendingDeepLink(recheckAfterEmpty: false, recheckAttempt: recheckAttempt + 1);
          });
        }
        return;
      }
      if (kDebugMode) debugPrint('🔗 [DeepLink] pushing BubbleLibraryPage then contentItemId=$contentItemId productId=$productId');
      final nav = rootNavKey.currentState;
      if (nav == null) {
        if (kDebugMode) debugPrint('🔗 [DeepLink] rootNavKey.currentState is null, skipping');
        return;
      }
      // 先進入「My Library」頁面，再依 payload 疊上該則卡片詳情或該產品庫
      nav.push(
        MaterialPageRoute(builder: (_) => const BubbleLibraryPage()),
      );
      if (contentItemId.isNotEmpty) {
        nav.push(
          MaterialPageRoute(builder: (_) => DetailPage(contentItemId: contentItemId)),
        );
      } else if (productId.isNotEmpty) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => ProductLibraryPage(productId: productId, isWishlistPreview: false),
          ),
        );
      }
      if (kDebugMode) debugPrint('🔗 [DeepLink] push done');
    } catch (e, st) {
      if (kDebugMode) debugPrint('🔗 [DeepLink] error: $e\n$st');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;

    // 未登入時直接不處理（避免 crash）
    String uid;
    try {
      uid = ref.read(uidProvider);
    } catch (_) {
      return;
    }

    // ✅ 初始化時區（在 Flutter 引擎完全啟動後，避免與插件註冊衝突）
    Future.microtask(() async {
      try {
        await TimezoneInit.ensureInitialized();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ 時區初始化失敗: $e');
        }
      }
    });

    // ✅ 透過 Provider 獲取 LearningProgressService（統一管理 Firestore 實例）
    final progress = ref.read(learningProgressServiceProvider);
    final libraryRepo = ref.read(libraryRepoProvider);

    // 配置 NotificationService 的 action callbacks
    // ✅ 重要：回調中必須 invalidate providers 以確保 UI 更新
    final ns = NotificationService();
    ns.configure(
      onLearned: (payload) async {
        if (kDebugMode) {
          debugPrint('📱 onLearned called with payload: $payload');
        }
        
        // payload 可能包含 contentId 或 contentItemId，統一處理
        final topicId = payload['topicId'] as String?;
        final contentId = payload['contentId'] as String? ??
            payload['contentItemId'] as String?;
        final pushOrderRaw = payload['pushOrder'];
        
        // JSON decode 後 pushOrder 可能是 num 而非 int，需要轉換
        int? pushOrder;
        if (pushOrderRaw is int) {
          pushOrder = pushOrderRaw;
        } else if (pushOrderRaw is num) {
          pushOrder = pushOrderRaw.toInt();
        }

        if (kDebugMode) {
          debugPrint('📋 Parsed: topicId=$topicId contentId=$contentId pushOrder=$pushOrder (raw: $pushOrderRaw, type: ${pushOrderRaw.runtimeType})');
        }

        // ✅ 降級邏輯：即使缺少 topicId 或 pushOrder，也使用 libraryRepo 標記為已學習
        if (contentId != null && contentId.isNotEmpty) {
          try {
            await libraryRepo.setSavedItem(uid, contentId, {'learned': true});
            if (kDebugMode) {
              debugPrint('✅ setSavedItem learned=true: contentId=$contentId');
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('❌ setSavedItem error: $e');
            }
          }
        }

        // 嘗試使用 LearningProgressService（如果資料完整）
        if (topicId != null && contentId != null && pushOrder != null) {
          try {
            await progress.markLearnedAndAdvance(
              topicId: topicId,
              contentId: contentId,
              pushOrder: pushOrder,
              source: 'ios_action',
            );
            // ✅ 確保 UI 更新：invalidate savedItemsProvider
            ref.invalidate(savedItemsProvider);
            ref.invalidate(libraryProductsProvider);
            if (kDebugMode) {
              debugPrint(
                  '✅ markLearnedAndAdvance: topicId=$topicId contentId=$contentId pushOrder=$pushOrder');
            }
          } catch (e, stackTrace) {
            // 忽略錯誤，已經用 setSavedItem 標記了
            if (kDebugMode) {
              debugPrint('⚠️ markLearnedAndAdvance failed (fallback used): $e');
              debugPrint('Stack trace: $stackTrace');
            }
          }
        }
        // 以「標記學會」為準：更新 streak（onLearned payload 無 productId，用全域）
        await UserLearningStore().markGlobalLearnedToday();
      },
      // ✅ 重新學習回調：重置產品進度並重新排程
      onRestart: (payload) async {
        if (kDebugMode) {
          debugPrint('🔄 onRestart called with payload: $payload');
        }
        
        final productId = payload['productId'] as String?;
        if (productId == null || productId.isEmpty) {
          if (kDebugMode) {
            debugPrint('❌ onRestart: productId is missing');
          }
          return;
        }
        
        try {
          // 獲取該商品的所有內容
          final contentItems = await ref.read(contentByProductProvider(productId).future);
          final contentItemIds = contentItems.map((e) => e.id).toList();
          
          // 獲取產品資訊（用於取得 topicId）
          final productsMap = await ref.read(productsMapProvider.future);
          final product = productsMap[productId];
          final topicId = product?.topicId;
          
          // ✅ 1. 取消該產品所有已排程的通知（確保舊通知不會干擾）
          final ns = NotificationService();
          await ns.cancelByProductId(productId);
          
          // ✅ 2. 清除該產品的排除數據（opened, missed, scheduled）
          await PushExclusionStore.clearProduct(uid, contentItemIds);
          
          // ✅ 3. 清除本地學習歷史
          final userLearningStore = UserLearningStore();
          await userLearningStore.clearProductHistory(productId);
          
          // ✅ 4. 執行重置（清除學習狀態、contentState、topicProgress，重新啟用推播）
          await libraryRepo.resetProductProgress(
            uid: uid,
            productId: productId,
            contentItemIds: contentItemIds,
            topicId: topicId,
          );
          
          // ✅ 5. 刷新 UI 並等待數據更新完成（確保重新排程時讀到最新狀態）
          ref.invalidate(savedItemsProvider);
          ref.invalidate(libraryProductsProvider);
          
          // 等待 provider 更新完成，確保重新排程時讀到清除後的數據
          try {
            await ref.read(savedItemsProvider.future);
            await ref.read(libraryProductsProvider.future);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ 等待 provider 更新失敗: $e');
            }
            // 繼續執行，push_orchestrator 內部也會等待
          }
          
          // ✅ 6. 重新排程（確保新的推播正常運作，並按新排程建立學習歷史）
          final scheduler = ref.read(notificationSchedulerProvider);
          await scheduler.schedule(
            ref: ref,
            days: 3,
            source: 'restart_action',
            immediate: true,
          );
          
          if (kDebugMode) {
            debugPrint('✅ onRestart: 已重新開始，推播已重新排程，學習歷史已清除');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ onRestart error: $e');
          }
        }
      },
      // ✅ 重排回調：在完成後重排未來 3 天
      onReschedule: () async {
        try {
          final scheduler = ref.read(notificationSchedulerProvider);
          await scheduler.schedule(
            ref: ref,
            days: 3,
            source: 'notification_action_callback',
            immediate: true, // 通知 action 後立即排程
          );
          // ✅ 確保 UI 更新：invalidate savedItemsProvider
          ref.invalidate(savedItemsProvider);
          if (kDebugMode) {
            debugPrint('🔄 onReschedule: 已重排未來 3 天');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ onReschedule error: $e');
          }
        }
      },
    );

    // ✅ 異步初始化 NotificationService
    Future.microtask(() async {
      await ns.init(
        uid: uid,
        lang: ref.read(appLanguageProvider),
        onTap: (data) {
          // 點擊通知本體
          final type = data['type'] as String?;
          
          // 完成通知：導航到產品設定頁面
          if (type == 'completion') {
            final productId = data['productId'] as String?;
            if (productId != null && mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductLibraryPage(
                    productId: productId,
                    isWishlistPreview: false,
                  ),
                ),
              );
            }
            return;
          }
          
          // 一般推播：導航到 DetailPage
          final contentItemId = data['contentItemId'] as String?;
          if (contentItemId != null && mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DetailPage(contentItemId: contentItemId),
              ),
            );
          }
        },
        onSelect: (payload, actionId) async {
          // #region agent log
          try {
            final logFile = File('/Users/Ariel/開發中APP/LearningBubbles/.cursor/debug.log');
            await logFile.writeAsString('{"sessionId":"debug-session","runId":"run1","hypothesisId":"D","location":"bootstrapper.dart:172","message":"onSelect callback started","data":{"actionId":"$actionId"},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append);
          } catch (_) {}
          // #endregion
          
          // ✅ 移除 addPostFrameCallback，改為直接執行或使用微任務
          // 背景下 addPostFrameCallback 可能永遠不會執行，導致 iOS 系統殺死進程
          try {
            await _handleNotificationAction(payload, actionId, ref, uid, progress);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('❌ onSelect error: $e');
            }
          }
        },
      );
    });

    // App 啟動：登入後會自動重排一次（若此刻未登入會略過）
    Future.microtask(() async {
      try {
        final scheduler = ref.read(notificationSchedulerProvider);
        await scheduler.schedule(
          ref: ref,
          days: 3,
          source: 'app_startup',
        );
      } catch (_) {}
    });

    // onepop://open 深層連結（Extension「查看完整內容」）：冷啟動時首幀後延遲再取回，與 resume 一致避免時序漏檢
    if (Platform.isIOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (kDebugMode) debugPrint('🔗 [DeepLink] cold start: scheduling _checkPendingDeepLink in 350ms');
        Future.delayed(const Duration(milliseconds: 350), () {
          if (!mounted) return;
          _checkPendingDeepLink();
        });
        // 冷啟動同步 Extension Done 狀態
        if (kDebugMode) debugPrint('✅ [ExtDone] cold start: scheduling pending done check in 500ms');
        Future.delayed(const Duration(milliseconds: 500), () async {
          if (!mounted) return;
          // 先查原生端暫存的 pending done item
          try {
            final pendingItemId = await _deepLinkChannel.invokeMethod<String>('getPendingDoneItemId') ?? '';
            if (pendingItemId.isNotEmpty) {
              if (kDebugMode) debugPrint('✅ [ExtDone] cold start: pendingDoneItemId=$pendingItemId');
              _handleExtensionDoneItem(pendingItemId);
              return;
            }
          } catch (e) {
            if (kDebugMode) debugPrint('❌ [ExtDone] getPendingDoneItemId error: $e');
          }
          // fallback：從 App Group 讀取（上次 App 關閉期間可能有按 Done）
          _syncExtensionCompletedState();
        });
      });
    }
  }

  /// 處理通知按鈕點擊（確保在主線程執行）
  /// 
  /// 狀態更新流程：
  /// 1. 先掃描過期的通知（sweepMissed）
  /// 2. 標記已讀/學習狀態（markOpened + LearningProgressService）
  /// 3. 重新排程未來推播（rescheduleNextDays）
  /// 4. 刷新 UI（_onStatusChanged）
  Future<void> _handleNotificationAction(
    String? payload,
    String? actionId,
    WidgetRef ref,
    String uid,
    LearningProgressService progress,
  ) async {
    // #region agent log
    try {
      final logFile = File('/Users/Ariel/開發中APP/LearningBubbles/.cursor/debug.log');
      await logFile.writeAsString('{"sessionId":"debug-session","runId":"run1","hypothesisId":"A,B,E","location":"bootstrapper.dart:195","message":"_handleNotificationAction started","data":{"actionId":"$actionId","mounted":$mounted},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append);
    } catch (_) {}
    // #endregion
    final data = PushOrchestrator.decodePayload(payload);
    if (data == null) return;

    // ✅ 自動標記已讀已在 NotificationService.init 內部處理（handlePayload）

    final productId = data['productId'] as String?;
    final contentItemId = data['contentItemId'] as String?;
    // ✅ 從 payload 獲取 topicId 和 pushOrder（已在 push_orchestrator 中加入）
    final topicId = data['topicId'] as String?;
    final contentId = data['contentId'] as String? ?? contentItemId;
    final pushOrderRaw = data['pushOrder'];

    final repo = ref.read(libraryRepoProvider);
    final ns = NotificationService();

    // action：先寫回資料
    final cid = contentItemId;
    final pid = productId;
    
    // 新的 2 個 action
    if (actionId == NotificationService.actionLearned && cid != null) {
      // ✅ 1) 先掃描過期的通知
      await PushExclusionStore.sweepExpired(uid);
      
      // ✅ 2) 標記為已讀（opened 優先於 missed）
      await PushExclusionStore.markOpened(uid, cid);
      
      // ✅ 3) 使用 LearningProgressService 標記為已學會（統一學習狀態管理）
      int? pushOrder;
      if (pushOrderRaw is int) {
        pushOrder = pushOrderRaw;
      } else if (pushOrderRaw is num) {
        pushOrder = pushOrderRaw.toInt();
      }

      if (topicId != null && contentId != null && pushOrder != null) {
        try {
          await progress.markLearnedAndAdvance(
            topicId: topicId,
            contentId: contentId,
            pushOrder: pushOrder,
            source: 'notification_action',
          );
          // ✅ 刷新 UI（LearningProgressService 已同步寫入 saved_items）
          ref.invalidate(savedItemsProvider);
          ref.invalidate(libraryProductsProvider);
          if (kDebugMode) {
            debugPrint('✅ LEARNED: product=$pid content=$cid -> advance next');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ markLearnedAndAdvance error: $e');
          }
          // 降級：如果 LearningProgressService 失敗，使用舊方法
          await repo.setSavedItem(uid, cid, {'learned': true});
          ref.invalidate(savedItemsProvider);
        }
      } else {
        // 如果 payload 缺少必要資訊，使用舊方法
        await repo.setSavedItem(uid, cid, {'learned': true});
        ref.invalidate(savedItemsProvider);
      }
      
      // 以「標記學會」為準：更新 streak
      if (pid != null && pid.isNotEmpty) {
        await UserLearningStore().markLearnedTodayAndGlobal(pid);
      } else {
        await UserLearningStore().markGlobalLearnedToday();
      }
      
      // ✅ 4) 取消該內容的推播
      await ns.cancelByContentItemId(cid);
      
      return; // ✅ actionLearned 處理完成，只標記完成，不導航
    }

    // 點通知本體：跳轉（延遲執行，確保 Flutter 引擎已準備好）
    // 注意：如果是點擊按鈕（actionId != null），且按鈕不是 actionLearned，則不應執行導航
    if (!mounted || actionId != null) return;
    
    // 只有點擊通知本體（actionId == null）才進行導航
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // #region agent log
      try {
        final logFile = File('/Users/Ariel/開發中APP/LearningBubbles/.cursor/debug.log');
        await logFile.writeAsString('{"sessionId":"debug-session","runId":"run1","hypothesisId":"B","location":"bootstrapper.dart:290","message":"PostFrameCallback started","data":{"mounted":$mounted},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append);
      } catch (_) {}
      // #endregion
      if (!mounted) return;
      
      // #region agent log
      try {
        final logFile = File('/Users/Ariel/開發中APP/LearningBubbles/.cursor/debug.log');
        await logFile.writeAsString('{"sessionId":"debug-session","runId":"run1","hypothesisId":"B","location":"bootstrapper.dart:293","message":"Before Navigator.push","timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append);
      } catch (_) {}
      // #endregion
      if (!mounted) return;
      if (cid != null) {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DetailPage(contentItemId: cid)));
        // #region agent log
        try {
          final logFile = File('/Users/Ariel/開發中APP/LearningBubbles/.cursor/debug.log');
          await logFile.writeAsString('{"sessionId":"debug-session","runId":"run1","hypothesisId":"B","location":"bootstrapper.dart:296","message":"After Navigator.push DetailPage","timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append);
        } catch (_) {}
        // #endregion
      } else if (pid != null) {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              ProductLibraryPage(productId: pid, isWishlistPreview: false),
        ));
        // #region agent log
        try {
          final logFile = File('/Users/Ariel/開發中APP/LearningBubbles/.cursor/debug.log');
          await logFile.writeAsString('{"sessionId":"debug-session","runId":"run1","hypothesisId":"B","location":"bootstrapper.dart:301","message":"After Navigator.push ProductLibraryPage","timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append);
        } catch (_) {}
        // #endregion
      }

      // 重排未來 3 天（延遲執行，避免插件註冊錯誤）
      // #region agent log
      try {
        final logFile = File('/Users/Ariel/開發中APP/LearningBubbles/.cursor/debug.log');
        await logFile.writeAsString('{"sessionId":"debug-session","runId":"run1","hypothesisId":"A","location":"bootstrapper.dart:305","message":"Before TimezoneInit and rescheduleNextDays","timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append);
      } catch (_) {}
      // #endregion
      try {
        // ✅ 確保時區已初始化
        await TimezoneInit.ensureInitialized();
        // #region agent log
        try {
          final logFile = File('/Users/Ariel/開發中APP/LearningBubbles/.cursor/debug.log');
          await logFile.writeAsString('{"sessionId":"debug-session","runId":"run1","hypothesisId":"A","location":"bootstrapper.dart:308","message":"After TimezoneInit, before rescheduleNextDays","timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append);
        } catch (_) {}
        // #endregion
        // ✅ 使用統一排程入口
        final scheduler = ref.read(notificationSchedulerProvider);
        await scheduler.schedule(
          ref: ref,
          days: 3,
          source: 'notification_tap',
        );
        // #region agent log
        try {
          final logFile = File('/Users/Ariel/開發中APP/LearningBubbles/.cursor/debug.log');
          await logFile.writeAsString('{"sessionId":"debug-session","runId":"run1","hypothesisId":"A","location":"bootstrapper.dart:310","message":"After rescheduleNextDays","timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append);
        } catch (_) {}
        // #endregion
      } catch (e) {
        // #region agent log
        try {
          final logFile = File('/Users/Ariel/開發中APP/LearningBubbles/.cursor/debug.log');
          await logFile.writeAsString('{"sessionId":"debug-session","runId":"run1","hypothesisId":"A","location":"bootstrapper.dart:312","message":"rescheduleNextDays error","data":{"error":"$e"},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append);
        } catch (_) {}
        // #endregion
        if (kDebugMode) {
          debugPrint('❌ rescheduleNextDays error: $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
