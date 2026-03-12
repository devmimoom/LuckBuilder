import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../notifications/scheduled_push_cache.dart';
import '../push_product_config_page.dart';
import '../../providers/providers.dart';
import '../../notifications/push_orchestrator.dart';
import '../../models/push_config.dart';
import 'bubble_card.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_tokens.dart';
import '../../../localization/app_language_provider.dart';
import '../../../localization/app_strings.dart';

class PushTimelineSection extends ConsumerStatefulWidget {
  final Future<void> Function(ScheduledPushEntry entry)? onSkip;

  const PushTimelineSection({super.key, this.onSkip});

  @override
  ConsumerState<PushTimelineSection> createState() => PushTimelineSectionState();
}

class PushTimelineSectionState extends ConsumerState<PushTimelineSection> {
  bool _loading = true;
  List<ScheduledPushEntry> _upcoming = const [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  /// 外部可呼叫此方法重新載入
  Future<void> reload() => _loadAll();

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final cache = ScheduledPushCache();

    final upcoming =
        await cache.loadSortedUpcoming(horizon: const Duration(days: 3));

    if (!mounted) return;
    setState(() {
      _upcoming = upcoming;
      _loading = false;
    });
  }

  /// ✅ 從 Firestore 讀取勿擾時段
  TimeOfDay _getQuietHoursStart() {
    final globalAsync = ref.watch(globalPushSettingsProvider);
    return globalAsync.maybeWhen(
      data: (g) => g.quietHours.start,
      orElse: () => const TimeOfDay(hour: 22, minute: 0),
    );
  }

  TimeOfDay _getQuietHoursEnd() {
    final globalAsync = ref.watch(globalPushSettingsProvider);
    return globalAsync.maybeWhen(
      data: (g) => g.quietHours.end,
      orElse: () => const TimeOfDay(hour: 8, minute: 0),
    );
  }

  String _dateHeader(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _time(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _getQuietHoursStart() : _getQuietHoursEnd();
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
    );
    if (picked == null) return;

    // ✅ 更新 Firestore 全域設定
    final uid = ref.read(uidProvider);
    final repo = ref.read(pushSettingsRepoProvider);
    final globalAsync = ref.read(globalPushSettingsProvider);
    
    globalAsync.whenData((g) async {
      final newQuietHours = isStart
          ? TimeRange(picked, g.quietHours.end)
          : TimeRange(g.quietHours.start, picked);
      final newSettings = g.copyWith(quietHours: newQuietHours);
      await repo.setGlobal(uid, newSettings);
      // 觸發重排（使用新設定）
      await PushOrchestrator.rescheduleNextDays(
        ref: ref,
        days: 3,
        overrideGlobal: newSettings,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final lang = ref.watch(appLanguageProvider);
    
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // group by date
    final Map<String, List<ScheduledPushEntry>> grouped = {};
    for (final e in _upcoming) {
      final key = _dateHeader(e.when);
      grouped.putIfAbsent(key, () => []).add(e);
    }
    final keys = grouped.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(uiString(lang, 'push_timeline_header'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: AppSpacing.xs),
        BubbleCard(
          child: _upcoming.isEmpty
              ? Text(uiString(lang, 'push_timeline_empty'),
                  style: TextStyle(color: tokens.textSecondary))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final day in keys) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs, top: AppSpacing.xs),
                        child: Text(
                          day,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      ...grouped[day]!.map((e) {
                        final productId =
                            e.payload['productId']?.toString() ?? '';
                        final contentItemId =
                            e.payload['contentItemId']?.toString() ?? '';

                        // title: productTitle only (or productId fallback)
                        final title = e.title.isNotEmpty ? e.title : productId;

                        // Day from payload (body no longer contains Day N/365)
                        final pushOrder = e.payload['pushOrder'];
                        final dayNum = pushOrder is int
                            ? pushOrder
                            : (pushOrder is num ? pushOrder.toInt() : null);
                        final dayText = dayNum == null
                            ? ''
                            : uiString(lang, 'day_number')
                                .replaceFirst('{n}', '$dayNum');

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Text(
                            _time(e.when),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            '$productId$dayText',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.onSkip != null &&
                                  contentItemId.isNotEmpty)
                                TextButton(
                                  onPressed: () async {
                                    await widget.onSkip!(e);
                                    await _loadAll(); // 跳過後重載 timeline
                                  },
                                  child: Text(uiString(lang, 'skip')),
                                ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: productId.isEmpty
                              ? null
                              : () {
                                  // 點 timeline → 直接去該商品推播設定頁
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => PushProductConfigPage(
                                        productId: productId),
                                  ));
                                },
                        );
                      }),
                      const Divider(height: 16),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(uiString(lang, 'quiet_hours_title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: AppSpacing.xs),
        // ✅ 從 Firestore 讀取勿擾時段
        ref.watch(globalPushSettingsProvider).when(
          data: (g) {
            return BubbleCard(
              child: Row(
                children: [
                  const Icon(Icons.bedtime),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(formatTimeRange(g.quietHours),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton(
                              onPressed: () => _pickTime(isStart: true),
                              child: Text(uiString(lang, 'start_label'))),
                          const SizedBox(width: 8),
                          OutlinedButton(
                              onPressed: () => _pickTime(isStart: false),
                              child: Text(uiString(lang, 'end_label'))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const BubbleCard(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) {
            final tokens = context.tokens;
            return BubbleCard(
              child: Text(uiString(lang, 'load_error_title'),
                  style: TextStyle(color: tokens.textSecondary)),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
              label: Text(uiString(lang, 'refresh_schedule')),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              uiString(lang, 'source_local_cache'),
              style: TextStyle(
                  color: context.tokens.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}
