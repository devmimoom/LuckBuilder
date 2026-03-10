import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../models/product.dart';
import '../models/push_config.dart';
import '../../localization/app_language_provider.dart';
import '../notifications/push_orchestrator.dart';
import '../notifications/push_scheduler.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_scheduler.dart';
import '../../notifications/push_exclusion_store.dart';
import '../../widgets/rich_sections/user_learning_store.dart';
import 'widgets/bubble_card.dart';
import '../../providers/analytics_provider.dart';
import '../../theme/app_tokens.dart';
import '../../localization/app_language.dart';
import '../../localization/app_strings.dart';

class PushProductConfigPage extends ConsumerWidget {
  final String productId;
  const PushProductConfigPage({super.key, required this.productId});

  static final _loggedConfigIds = <String>{};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_loggedConfigIds.contains(productId)) {
      _loggedConfigIds.add(productId);
      ref.read(analyticsProvider).logScreenView(screenName: 'push_config');
    }
    final lang = ref.watch(appLanguageProvider);
    // 檢查是否登入
    String? uid;
    try {
      uid = ref.read(uidProvider);
    } catch (_) {
      return Scaffold(
        appBar: AppBar(title: Text(uiString(lang, 'product_notifications_title'))),
        body: Center(child: Text(uiString(lang, 'sign_in_to_use_feature'))),
      );
    }
    final libAsync = ref.watch(libraryProductsProvider);
    final productsAsync = ref.watch(productsMapProvider);
    final globalAsync = ref.watch(globalPushSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(uiString(lang, 'product_notifications_title'))),
      body: productsAsync.when(
        data: (products) => globalAsync.when(
          data: (global) => libAsync.when(
            data: (lib) {
              final lp = lib.firstWhere((e) => e.productId == productId);
              final title = products[productId]?.displayTitle(lang) ?? productId;
              final cfg = lp.pushConfig;
              
              // 計算所有啟用推播的商品的總頻率
              final totalFreq = lib
                  .where((e) => e.pushEnabled && !e.isHidden)
                  .fold<int>(0, (sum, e) => sum + e.pushConfig.freqPerDay);

              return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                BubbleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      
                      // 顯示完成狀態
                      if (lp.completedAt != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.tokens.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.tokens.primary),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.emoji_events, 
                                color: context.tokens.primary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      uiString(lang, 'push_all_done'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: context.tokens.primary,
                                      ),
                                    ),
                                    Text(
                                      uiString(lang, 'all_done_completed_at').replaceFirst(
                                        '{date}',
                                        '${lp.completedAt!.month}/${lp.completedAt!.day} ${lp.completedAt!.hour}:${lp.completedAt!.minute.toString().padLeft(2, '0')}',
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.tokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // 重新開始按鈕
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showRestartDialog(
                                context, ref, uid!, productId, title, lang),
                            icon: const Icon(Icons.restart_alt),
                            label: Text(uiString(lang, 'start_over')),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      SwitchListTile.adaptive(
                        value: lp.pushEnabled,
                        onChanged: (v) async {
                          await ref
                              .read(libraryRepoProvider)
                              .setPushEnabled(uid!, productId, v);
                          ref.invalidate(libraryProductsProvider);
                          await ref.read(libraryProductsProvider.future);
                          await PushOrchestrator.rescheduleNextDays(
                              ref: ref, days: 3);
                        },
                        title: Text(uiString(lang, 'notifications_on')),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await NotificationService()
                                .showTestBubbleNotificationForProduct(
                              productId: productId,
                              productTitle: title,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text(uiString(lang, 'test_notification_sent')),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.campaign, size: 18),
                          label: Text(uiString(lang, 'send_test_notification')),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                BubbleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(uiString(lang, 'time_mode'),
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      RadioListTile<PushTimeMode>(
                        value: PushTimeMode.preset,
                        groupValue: cfg.timeMode, // ignore: deprecated_member_use
                        onChanged: (v) async { // ignore: deprecated_member_use
                          if (v == null) return;
                          final newCfg = cfg.copyWith(timeMode: v);
                          await ref
                              .read(libraryRepoProvider)
                              .setPushConfig(uid!, productId, newCfg.toMap());
                          ref.invalidate(libraryProductsProvider);
                          await ref.read(libraryProductsProvider.future);
                          await PushOrchestrator.rescheduleNextDays(
                              ref: ref, days: 3);
                        },
                        title: Text(uiString(lang, 'preset_recommended')),
                      ),
                      if (cfg.timeMode == PushTimeMode.preset) ...[
                        _presetSlots(ref, uid!, productId, cfg),
                        const SizedBox(height: 16),
                        Text(uiString(lang, 'frequency_label'),
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        DropdownButton<int>(
                          value: cfg.freqPerDay,
                          dropdownColor: context.tokens.cardBg,
                          items: const [1, 2, 3, 4, 5]
                              .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(uiString(lang, 'per_day_suffix')
                                      .replaceFirst('{n}', '$e'))))
                              .toList(),
                          onChanged: (v) async {
                            if (v == null) return;
                            final newCfg = cfg.copyWith(freqPerDay: v);
                            await ref
                                .read(libraryRepoProvider)
                                .setPushConfig(uid!, productId, newCfg.toMap());
                            ref.invalidate(libraryProductsProvider);
                            await ref.read(libraryProductsProvider.future);
                            await PushOrchestrator.rescheduleNextDays(
                                ref: ref, days: 3);
                          },
                        ),
                        if (totalFreq > global.dailyTotalCap) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.amber.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        uiString(lang, 'total_freq_exceeds_cap'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.amber.shade800,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        uiString(lang, 'total_freq_exceeds_cap_detail')
                                            .replaceFirst('{total}', '$totalFreq')
                                            .replaceFirst('{cap}', '${global.dailyTotalCap}'),
                                        style: TextStyle(
                                          color: Colors.amber.shade800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      RadioListTile<PushTimeMode>(
                        value: PushTimeMode.custom,
                        groupValue: cfg.timeMode, // ignore: deprecated_member_use
                        onChanged: (v) async { // ignore: deprecated_member_use
                          if (v == null) return;
                          final newCfg = cfg.copyWith(timeMode: v);
                          
                          // 調試：確認保存的配置
                          if (kDebugMode) {
                            final savedMap = newCfg.toMap();
                            debugPrint('💾 切換到自訂時間模式 - productId: $productId');
                            debugPrint('   - timeMode: ${savedMap['timeMode']}');
                            debugPrint('   - customTimes: ${savedMap['customTimes']}');
                          }
                          
                          await ref
                              .read(libraryRepoProvider)
                              .setPushConfig(uid!, productId, newCfg.toMap());
                          ref.invalidate(libraryProductsProvider);
                          await ref.read(libraryProductsProvider.future);
                          await PushOrchestrator.rescheduleNextDays(
                              ref: ref, days: 3);
                        },
                        title: Text(uiString(lang, 'custom_times_title')),
                      ),
                      if (cfg.timeMode == PushTimeMode.custom)
                        _customTimes(context, ref, uid!, productId, cfg, lang),
                    ],
                  ),
                ),
              ],
            );
          },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                uiString(lang, 'library_load_error'),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              uiString(lang, 'notification_settings_error'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            uiString(lang, 'product_load_error'),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _presetSlots(
      WidgetRef ref, String uid, String productId, PushConfig cfg) {
    // ✅ 新的8个固定2小时时间段
    const slots = ['7-9', '9-11', '11-13', '13-15', '15-17', '17-19', '19-21', '21-23'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((s) {
            final selected = cfg.presetSlots.contains(s);
            return FilterChip(
              selected: selected,
              label: Text(formatTimeRange(PushScheduler.presetSlotRanges[s]!)),
              onSelected: (v) async {
                final newSlots = List<String>.from(cfg.presetSlots);
                if (v) {
                  newSlots.add(s);
                } else {
                  newSlots.remove(s);
                }
                // ✅ 默认时间段改为 21-23
                final fixed = newSlots.isEmpty ? ['21-23'] : newSlots;
                final newCfg = cfg.copyWith(presetSlots: fixed);
                await ref
                    .read(libraryRepoProvider)
                    .setPushConfig(uid, productId, newCfg.toMap());
                ref.invalidate(libraryProductsProvider);
                await ref.read(libraryProductsProvider.future);
                await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _customTimes(BuildContext context, WidgetRef ref, String uid,
      String productId, PushConfig cfg, AppLanguage lang) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              if (cfg.customTimes.length >= 5) return;
              final t = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 21, minute: 40));
              if (t == null) return;

              final list = List<TimeOfDay>.from(cfg.customTimes)..add(t);
              list.sort((a, b) =>
                  (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));

              // ✅ 確保 timeMode 為 custom（當用戶新增自訂時間時）
              final newCfg = cfg.copyWith(
                customTimes: list,
                timeMode: PushTimeMode.custom, // 確保時間模式為自訂
              );
              
              // 調試：確認保存的配置
              if (kDebugMode) {
                final savedMap = newCfg.toMap();
                debugPrint('💾 保存推播配置 - productId: $productId');
                debugPrint('   - timeMode: ${savedMap['timeMode']}');
                debugPrint('   - customTimes: ${savedMap['customTimes']}');
              }
              
              await ref
                  .read(libraryRepoProvider)
                  .setPushConfig(uid, productId, newCfg.toMap());
              ref.invalidate(libraryProductsProvider);
              await ref.read(libraryProductsProvider.future);
              await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
            },
            icon: const Icon(Icons.add),
            label: Text(uiString(lang, 'add_time_btn')),
          ),
        ),
        ...cfg.customTimes.map((t) => ListTile(
              title: Text(
                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () async {
                  final list = List<TimeOfDay>.from(cfg.customTimes)
                    ..removeWhere(
                        (x) => x.hour == t.hour && x.minute == t.minute);

                  // 如果刪除後沒有自訂時間了，可以選擇回退到預設模式，但這裡保持 custom 模式
                  final newCfg = cfg.copyWith(customTimes: list);
                  
                  // 調試：確認保存的配置
                  if (kDebugMode) {
                    final savedMap = newCfg.toMap();
                    debugPrint('💾 刪除自訂時間後保存推播配置 - productId: $productId');
                    debugPrint('   - timeMode: ${savedMap['timeMode']}');
                    debugPrint('   - customTimes: ${savedMap['customTimes']} (剩餘 ${list.length} 個)');
                  }
                  
                  await ref
                      .read(libraryRepoProvider)
                      .setPushConfig(uid, productId, newCfg.toMap());
                  ref.invalidate(libraryProductsProvider);
                  await ref.read(libraryProductsProvider.future);
                  await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
                },
              ),
            )),
      ],
    );
  }

  /// 顯示重新開始確認對話框
  Future<void> _showRestartDialog(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String productId,
    String productTitle,
    AppLanguage lang,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(uiString(lang, 'start_over_title')),
        content: Text(uiString(lang, 'start_over_content')
            .replaceFirst('{product}', productTitle)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(uiString(lang, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(uiString(lang, 'start_over_confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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
      final repo = ref.read(libraryRepoProvider);
      await repo.resetProductProgress(
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
      
      // ✅ 6. 重新排程（使用統一排程入口，確保新的推播正常運作）
      final scheduler = ref.read(notificationSchedulerProvider);
      await scheduler.schedule(
        ref: ref,
        days: 3,
        source: 'ui_restart_action',
        immediate: true,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uiString(lang, 'started_over_toast')),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ _showRestartDialog error: $e');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiString(lang, 'reset_failed_with_reason')
                  .replaceFirst('{error}', '$e'),
            ),
          ),
        );
      }
    }
  }
}
