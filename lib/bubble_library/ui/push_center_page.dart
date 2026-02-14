import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/global_push_settings.dart';
import '../models/push_config.dart';
import '../notifications/push_orchestrator.dart';
import '../notifications/notification_service.dart';
import '../providers/providers.dart';
import 'push_product_config_page.dart';
import 'widgets/bubble_card.dart';
import '../../../pages/push_timeline_page.dart';
import '../../../notifications/push_timeline_provider.dart';
import '../../../providers/analytics_provider.dart';
import '../../theme/app_tokens.dart';

class PushCenterPage extends ConsumerWidget {
  const PushCenterPage({super.key});

  static bool _didLogScreen = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_didLogScreen) {
      _didLogScreen = true;
      ref.read(analyticsProvider).logScreenView(screenName: 'push_center');
    }
    final globalAsync = ref.watch(globalPushSettingsProvider);
    final libAsync = ref.watch(libraryProductsProvider);
    final productsAsync = ref.watch(productsMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.timeline),
            tooltip: 'Next 3 days schedule',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PushTimelinePage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              try {
                final result = await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
                if (!context.mounted) return;
                if (result.overCap) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Total notifications exceed daily cap (${result.totalEffectiveFreq} > ${result.dailyCap}). Some may be skipped.',
                      ),
                    ),
                  );
                  return;
                }
                final global = await ref.read(globalPushSettingsProvider.future);
                final scheduled = await ref.read(scheduledCacheProvider.future);
                if (!context.mounted) return;
                final message = !global.enabled
                    ? 'Notifications are off. Cannot schedule.'
                    : scheduled.isEmpty
                        ? 'Rescheduled but no notifications generated. Check product settings.'
                        : 'Rescheduled ${scheduled.length} notifications for the next 3 days.';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              } catch (e) {
                if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Reschedule failed: $e')),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.campaign),
            tooltip: 'Send a test notification',
            onPressed: () async {
              await NotificationService().showTestBubbleNotification();
              // ignore: use_build_context_synchronously
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test notification sent.')),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          globalAsync.when(
            data: (g) => _globalCard(context, ref, g),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('global error: $e'),
          ),

          const SizedBox(height: 12),
          const Text('Active',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          productsAsync.when(
            data: (products) {
              return libAsync.when(
                data: (lib) {
                  final pushing =
                      lib.where((e) => !e.isHidden && e.pushEnabled).toList();
                  final completed =
                      lib.where((e) => !e.isHidden && !e.pushEnabled && e.completedAt != null).toList();
                  
                  if (pushing.isEmpty && completed.isEmpty) {
                    final tokens = context.tokens;
                    return BubbleCard(
                        child: Text('No products with notifications on',
                            style: TextStyle(
                                color: tokens.textSecondary)));
                  }
                  
                  return Column(
                    children: [
                      // 推播中的商品
                      ...pushing.map((lp) {
                      final title =
                          products[lp.productId]?.title ?? lp.productId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: BubbleCard(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => PushProductConfigPage(
                                    productId: lp.productId)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.notifications_active, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 6),
                                    Text(
                                        '${lp.pushConfig.freqPerDay}/day · ${lp.pushConfig.timeMode.name}',
                                        style: TextStyle(
                                            color: context.tokens.textSecondary,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                      
                      // 已完成的商品
                      if (completed.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        BubbleCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.emoji_events, 
                                    size: 20, 
                                    color: context.tokens.primary),
                                  const SizedBox(width: 8),
                                  Text('All done',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: context.tokens.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...completed.map((lp) {
                                final title = products[lp.productId]?.title ?? lp.productId;
                                final completedDate = lp.completedAt != null
                                    ? '${lp.completedAt!.month}/${lp.completedAt!.day}'
                                    : '';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PushProductConfigPage(
                                          productId: lp.productId,
                                        ),
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          Icon(Icons.check_circle, 
                                            size: 20, 
                                            color: context.tokens.primary),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(title,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          if (completedDate.isNotEmpty)
                                            Text(completedDate,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: context.tokens.textSecondary,
                                              ),
                                            ),
                                          const SizedBox(width: 8),
                                          Icon(Icons.chevron_right,
                                            size: 18,
                                            color: context.tokens.textSecondary),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => const Text(
                  'We couldn’t load your notification settings. Please try again later.',
                  textAlign: TextAlign.left,
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const Text(
              'We couldn’t load your products right now. Please try again later.',
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _globalCard(
      BuildContext context, WidgetRef ref, GlobalPushSettings g) {
    final uid = ref.read(uidProvider);
    final repo = ref.read(pushSettingsRepoProvider);

    return BubbleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Global settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          SwitchTheme(
            data: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Theme.of(context).colorScheme.primary;
                }
                return null;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Theme.of(context).colorScheme.primary.withValues(alpha: 0.5);
                }
                return null;
              }),
            ),
            child: SwitchListTile.adaptive(
              value: g.enabled,
              onChanged: (v) async {
                final newSettings = g.copyWith(enabled: v);
                // ✅ 並行執行：寫入 Firestore 和重排同時進行
                final writeFuture = repo.setGlobal(uid, newSettings);
                final rescheduleFuture = PushOrchestrator.rescheduleNextDays(
                  ref: ref,
                  days: 3,
                  overrideGlobal: newSettings,
                );
                await Future.wait([writeFuture, rescheduleFuture]);
              },
              title: const Text('Enable notifications'),
            ),
          ),
          ListTile(
            title: const Text('Daily cap (all products)'),
            subtitle: Text('${g.dailyTotalCap} per day'),
            trailing: DropdownButton<int>(
              value: g.dailyTotalCap,
              // ✅ 修復深色主題下拉選單透明背景重疊問題
              dropdownColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF14182E)
                  : null,
              items: (() {
                const presets = <int>[6, 8, 12, 20];
                final values = {...presets, g.dailyTotalCap}.toList()..sort();
                return values.map((e) {
                  final label =
                      presets.contains(e) ? '$e' : '$e (custom)';
                  return DropdownMenuItem(value: e, child: Text(label));
                }).toList();
              })(),
              onChanged: (v) async {
                if (v == null) return;
                final newSettings = g.copyWith(dailyTotalCap: v);
                try {
                  // ✅ 並行執行：寫入 Firestore 和重排同時進行
                  final writeFuture = repo.setGlobal(uid, newSettings);
                  final rescheduleFuture = PushOrchestrator.rescheduleNextDays(
                    ref: ref,
                    days: 3,
                    overrideGlobal: newSettings,
                  );
                  await Future.wait([writeFuture, rescheduleFuture]);
                  // ignore: use_build_context_synchronously
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Daily cap updated to $v.')),
                    );
                  }
                } catch (e) {
                  // ignore: use_build_context_synchronously
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Update failed: $e')),
                    );
                  }
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'If total notifications exceed the daily cap, some may be delayed.',
                    style: TextStyle(
                      color: context.tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ✅ 勿擾 / 靜音時段（全域）
          ListTile(
            title: const Text('Quiet hours (global)'),
            subtitle: Text(formatTimeRange(g.quietHours)),
            trailing: const Icon(Icons.bedtime_outlined),
            onTap: () async {
              final start = await _pickTime(context, g.quietHours.start);
              if (start == null) return;
              if (!context.mounted) return;
              final end = await _pickTime(context, g.quietHours.end);
              if (end == null) return;

              final next = g.copyWith(
                quietHours: TimeRange(start, end),
              );

              // ✅ 並行執行：寫入 Firestore 和重排同時進行
              final writeFuture = repo.setGlobal(uid, next);
              final rescheduleFuture = PushOrchestrator.rescheduleNextDays(
                ref: ref,
                days: 3,
                overrideGlobal: next,
              );
              await Future.wait([writeFuture, rescheduleFuture]);

              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Quiet hours set: ${formatTimeRange(TimeRange(start, end))}')),
              );
            },
          ),
          // （可選）快速關閉勿擾
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.restore),
              label: const Text('Turn off quiet hours'),
              onPressed: () async {
                final next = g.copyWith(
                  quietHours: const TimeRange(
                    TimeOfDay(hour: 0, minute: 0),
                    TimeOfDay(hour: 0, minute: 0),
                  ),
                );
                // ✅ 並行執行：寫入 Firestore 和重排同時進行
                final writeFuture = repo.setGlobal(uid, next);
                final rescheduleFuture = PushOrchestrator.rescheduleNextDays(
                  ref: ref,
                  days: 3,
                  overrideGlobal: next,
                );
                await Future.wait([writeFuture, rescheduleFuture]);

                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Quiet hours turned off (00:00 - 00:00).')),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Text('Changes will auto-reschedule the next 3 days.',
              style: TextStyle(
                  color: context.tokens.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Future<TimeOfDay?> _pickTime(BuildContext context, TimeOfDay initial) {
    return showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        // 讓顏色不要太突兀（可留可不留）
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(backgroundColor: Theme.of(context).colorScheme.surface),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
