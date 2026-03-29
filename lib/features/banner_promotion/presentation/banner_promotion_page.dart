import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/banner_notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/home_mesh_reference_colors.dart';
import '../../../core/theme/home_page_fonts.dart';
import '../../../core/utils/app_ux.dart';
import '../../../core/utils/paywall_gate.dart';
import '../../subscription/providers/feature_trial_provider.dart';
import '../../../core/widgets/glass_compact_card_shell.dart';
import '../models/banner_catalog.dart';
import '../models/banner_item.dart';
import '../models/banner_schedule_snapshot.dart';
import '../providers/banner_promotion_provider.dart';

/// 預設時段（與 Excel 推播節奏對齊的 8 格兩小時區間）
const List<({int startHour, int endHour})> kDefaultSlotRanges = [
  (startHour: 7, endHour: 9),
  (startHour: 9, endHour: 11),
  (startHour: 11, endHour: 13),
  (startHour: 13, endHour: 15),
  (startHour: 15, endHour: 17),
  (startHour: 17, endHour: 19),
  (startHour: 19, endHour: 21),
  (startHour: 21, endHour: 23),
];

String _formatSlotRange(int index) {
  final r = kDefaultSlotRanges[index];
  final a = r.startHour.toString().padLeft(2, '0');
  final b = r.endHour.toString().padLeft(2, '0');
  return '$a:00 - $b:00';
}

TimeOfDay _midpointForSlot(int index) {
  final r = kDefaultSlotRanges[index];
  final mid = (r.startHour + r.endHour) ~/ 2;
  return TimeOfDay(hour: mid, minute: 0);
}

Widget _bannerChineseExampleBlock(BannerItem? example) {
  if (example == null) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        '目前資料中找不到國文範例；開啟推播後仍會依你所選科目與單元取用內容。',
        style: HomePageFonts.resolve(const TextStyle(
          fontSize: AppFonts.sizeBodySm,
          height: AppFonts.lineHeightRelaxed,
          color: AppColors.textSecondary,
        )),
      ),
    );
  }

  final bannerBody = BannerNotificationService.instance
      .truncateForNotificationBody(example.content);

  TextStyle labelStyle() => HomePageFonts.resolve(const TextStyle(
        fontSize: AppFonts.sizeCaption,
        fontWeight: AppFonts.weightSemibold,
        color: AppColors.textSecondary,
        height: AppFonts.lineHeightBody,
      ));

  TextStyle bodyStyle() => HomePageFonts.resolve(const TextStyle(
        fontSize: AppFonts.sizeBodySm,
        height: AppFonts.lineHeightRelaxed,
        color: AppColors.textPrimary,
      ));

  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: HomeMeshReferenceColors.glassFillLight.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: HomeMeshReferenceColors.glassBorderWhite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '範例｜國文（資料中的一則）',
            style: HomePageFonts.resolve(const TextStyle(
              fontSize: AppFonts.sizeBodySm,
              fontWeight: AppFonts.weightSemibold,
              color: AppColors.textPrimary,
            )),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${example.itemId} · ${example.productId}',
            style: HomePageFonts.resolve(const TextStyle(
              fontSize: AppFonts.sizeCaption,
              color: AppColors.textTertiary,
            )),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('通知標題（橫幅標題）', style: labelStyle()),
          const SizedBox(height: AppSpacing.xs),
          Text(
            example.pushTitle.isNotEmpty ? example.pushTitle : '（無標題）',
            style: HomePageFonts.resolve(const TextStyle(
              fontSize: AppFonts.sizeBodySm,
              fontWeight: AppFonts.weightSemibold,
              height: AppFonts.lineHeightRelaxed,
              color: AppColors.textPrimary,
            )),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '橫幅內文預覽（通知列／橫幅常見長度，過長已截斷）',
            style: labelStyle(),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(bannerBody, style: bodyStyle()),
          const SizedBox(height: AppSpacing.sm),
          Text('完整推播內容（教材原文）', style: labelStyle()),
          const SizedBox(height: AppSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                border: Border.all(
                  color: HomeMeshReferenceColors.glassBorderWhite,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: SelectableText(
                  example.content,
                  style: bodyStyle(),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _bannerHelpLine(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '•',
            style: HomePageFonts.resolve(const TextStyle(
              fontSize: AppFonts.sizeBodySm,
              color: AppColors.textPrimary,
              fontWeight: AppFonts.weightBold,
            )),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: HomePageFonts.resolve(const TextStyle(
              fontSize: AppFonts.sizeBodySm,
              height: AppFonts.lineHeightRelaxed,
              color: AppColors.textSecondary,
            )),
          ),
        ),
      ],
    ),
  );
}

class BannerPromotionPage extends ConsumerStatefulWidget {
  const BannerPromotionPage({super.key});

  @override
  ConsumerState<BannerPromotionPage> createState() =>
      _BannerPromotionPageState();
}

class _BannerPromotionPageState extends ConsumerState<BannerPromotionPage> {
  String? _segment;
  String? _semester;
  String? _subSegment;
  final Set<String> _selectedProductIds = {};
  final Set<int> _selectedSlotIndices = {};

  /// true = 預設時段格線；false = 自訂時段
  bool _useDefaultSlots = true;
  int _frequency = 1;

  /// 最近一次成功開啟推播時儲存的摘要（與「橫幅通知功能說明」區塊分開顯示）。
  BannerScheduleSnapshot? _activeScheduleSnapshot;
  final List<TimeOfDay> _customTimes = [];

  void _resetFromSegment(BannerCatalog catalog, {String? preferredSegment}) {
    final segs = catalog.segments;
    _segment = preferredSegment != null && segs.contains(preferredSegment)
        ? preferredSegment
        : (segs.isEmpty ? null : segs.first);
    _semester = null;
    _subSegment = null;
    _selectedProductIds.clear();
    if (_segment != null) {
      final semesters = catalog.semestersForSegment(_segment!);
      _semester = semesters.isEmpty ? null : semesters.first;
      if (_semester != null) {
        final subs = catalog.subSegmentsFor(_segment!, _semester!);
        _subSegment = subs.isEmpty ? null : subs.first;
      }
    }
  }

  void _resetFromSemester(BannerCatalog catalog, String? semester) {
    _semester = semester;
    _subSegment = null;
    _selectedProductIds.clear();
    if (_segment != null && _semester != null) {
      final subs = catalog.subSegmentsFor(_segment!, _semester!);
      _subSegment = subs.isEmpty ? null : subs.first;
    }
  }

  void _toggleProduct(String id) {
    setState(() {
      if (_selectedProductIds.contains(id)) {
        _selectedProductIds.remove(id);
      } else {
        _selectedProductIds.add(id);
      }
    });
  }

  void _toggleSlot(int index) {
    setState(() {
      if (_selectedSlotIndices.contains(index)) {
        _selectedSlotIndices.remove(index);
      } else {
        _selectedSlotIndices.add(index);
      }
    });
  }

  Future<void> _pickCustomTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (t != null) {
      setState(() => _customTimes.add(t));
    }
  }

  /// 產生每日 [_frequency] 個觸發時間（輪詢已選時段）。
  List<TimeOfDay> _buildScheduleTimes() {
    if (_useDefaultSlots) {
      if (_selectedSlotIndices.isEmpty) return [];
      final mids = _selectedSlotIndices.map(_midpointForSlot).toList()
        ..sort((a, b) {
          final ah = a.hour * 60 + a.minute;
          final bh = b.hour * 60 + b.minute;
          return ah.compareTo(bh);
        });
      final out = <TimeOfDay>[];
      for (var i = 0; i < _frequency; i++) {
        final base = mids[i % mids.length];
        final addMin = (i ~/ mids.length) * 4;
        out.add(TimeOfDay(
          hour: base.hour,
          minute: (base.minute + addMin) % 60,
        ));
      }
      return out;
    }
    if (_customTimes.isEmpty) return [];
    final sorted = [..._customTimes]..sort((a, b) {
        final ah = a.hour * 60 + a.minute;
        final bh = b.hour * 60 + b.minute;
        return ah.compareTo(bh);
      });
    final out = <TimeOfDay>[];
    for (var i = 0; i < _frequency; i++) {
      final base = sorted[i % sorted.length];
      final addMin = (i ~/ sorted.length) * 4;
      out.add(TimeOfDay(
        hour: base.hour,
        minute: (base.minute + addMin) % 60,
      ));
    }
    return out;
  }

  int get _totalDailyEstimate =>
      _selectedProductIds.length * _frequency;

  BannerScheduleSnapshot _buildScheduleSnapshotForSave() {
    return BannerScheduleSnapshot(
      segment: _segment ?? '',
      semester: _semester ?? '',
      subSegment: _subSegment ?? '',
      productIds: _selectedProductIds.toList()..sort(),
      frequency: _frequency,
      useDefaultSlots: _useDefaultSlots,
      slotIndices: _selectedSlotIndices.toList()..sort(),
      customTimeStrings:
          _customTimes.map((t) => '${t.hour}:${t.minute}').toList(),
    );
  }

  Future<void> _reloadActiveScheduleSnapshot() async {
    final snap =
        await BannerNotificationService.instance.loadScheduleSnapshot();
    if (!mounted) return;
    setState(() => _activeScheduleSnapshot = snap);
  }

  String _describeActiveSchedule(BannerScheduleSnapshot s) {
    final freq = '每天 ${s.frequency} 則';
    if (s.useDefaultSlots && s.slotIndices.isNotEmpty) {
      final slots = [...s.slotIndices]..sort();
      final slotText = slots.map(_formatSlotRange).join('、');
      return '$freq；預設時段：$slotText';
    }
    if (!s.useDefaultSlots && s.customTimeStrings.isNotEmpty) {
      final times = s.customTimeStrings.map(_formatStoredCustomTime).join('、');
      return '$freq；自訂時段：$times';
    }
    return freq;
  }

  String _formatStoredCustomTime(String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) return stored;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Widget _scheduleSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: HomePageFonts.resolve(const TextStyle(
                fontSize: AppFonts.sizeCaption,
                fontWeight: AppFonts.weightSemibold,
                color: AppColors.textSecondary,
                height: AppFonts.lineHeightBody,
              )),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: HomePageFonts.resolve(const TextStyle(
                fontSize: AppFonts.sizeBodySm,
                height: AppFonts.lineHeightRelaxed,
                color: AppColors.textPrimary,
              )),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onEnable(BannerCatalog catalog) async {
    AppUX.feedbackClick();
    final seg = _segment;
    final sem = _semester;
    if (seg == null || sem == null) return;
    if (_selectedProductIds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請至少選擇一個推播單元（產品）')),
      );
      return;
    }
    if (_useDefaultSlots && _selectedSlotIndices.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請在「預設」模式下至少選擇一個時段')),
      );
      return;
    }
    if (!_useDefaultSlots && _customTimes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請在「自訂時段」下至少新增一個時間')),
      );
      return;
    }

    final items = catalog.itemsForProductsBySemester(
      seg,
      sem,
      _selectedProductIds,
      subSegment: _subSegment ?? '',
    );
    if (items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所選單元尚無橫幅資料')),
      );
      return;
    }

    final times = _buildScheduleTimes();
    if (times.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法建立推播時間，請檢查時段設定')),
      );
      return;
    }

    if (!await PaywallGate.consumeTrialIfNeeded(
      context,
      ref,
      TrialFeature.bannerPromotion,
    )) {
      return;
    }

    try {
      await BannerNotificationService.instance.enableBannerSchedule(
        items: items,
        timesOfDay: times,
        scheduleSnapshot: _buildScheduleSnapshotForSave(),
      );
      await _reloadActiveScheduleSnapshot();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Platform.isIOS
                ? '已開啟橫幅通知（每日 $_frequency 則，依時段重複）'
                : '已儲存設定；本地排程僅在 iOS 裝置上生效',
          ),
        ),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      if (e.message == 'NOT_PERMITTED') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('尚未允許通知，請到「設定」開啟通知權限。'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('無法開啟：${e.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('開啟失敗：$e')),
      );
    }
  }

  Future<void> _onDisable() async {
    AppUX.feedbackClick();
    try {
      await BannerNotificationService.instance.disableBannerNotifications();
      await _reloadActiveScheduleSnapshot();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已關閉橫幅通知並取消排程')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('關閉失敗：$e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _reloadActiveScheduleSnapshot());
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bannerCatalogProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('學習橫幅推播'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: async.when(
        data: (catalog) {
          if (catalog.items.isEmpty) {
            return Center(
              child: Text(
                '尚無橫幅資料',
                style: HomePageFonts.resolve(const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFonts.sizeBodyLg,
                )),
              ),
            );
          }
          if (_segment == null) {
            Future.microtask(() {
              if (!mounted || _segment != null) return;
              setState(() => _resetFromSegment(catalog));
            });
          }

          final segments = catalog.segments;
          final semesters = _segment != null
              ? catalog.semestersForSegment(_segment!)
              : <String>[];
          final subSegments = (_segment != null && _semester != null)
              ? catalog.subSegmentsFor(_segment!, _semester!)
              : <String>[];
          final products = (_segment != null && _semester != null)
              ? catalog.productsForSemester(
                  _segment!,
                  _semester!,
                  subSegment: _subSegment ?? '',
                )
              : <String>[];

          final overGlobal =
              _totalDailyEstimate > 20 && _selectedProductIds.isNotEmpty;

          return ListView(
            padding: AppSpacing.screenPadding,
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1).withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(
                    color: const Color(0xFFFFC107).withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.amber.shade800,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '提醒：橫幅推播內容屬於重點整理與學習補充，目的是協助複習與提醒。正式學習仍請以課本、課堂講解與老師指定教材為主，避免將推播內容作為唯一學習依據。',
                        style: HomePageFonts.resolve(const TextStyle(
                          fontSize: AppFonts.sizeBodySm,
                          height: AppFonts.lineHeightRelaxed,
                          color: AppColors.textPrimary,
                        )),
                      ),
                    ),
                  ],
                ),
              ),
              _BannerGlassSection(
                title: '選擇範圍',
                subtitle: '選擇科目與學期，再複選推播單元；有子科目時可進一步篩選。',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabeledDropdown<String>(
                      label: '科目',
                      value: _segment,
                      items: segments,
                      onChanged: (v) {
                        setState(() {
                          _resetFromSegment(catalog, preferredSegment: v);
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _LabeledDropdown<String>(
                      label: '學期',
                      value: _semester,
                      items: semesters,
                      labelBuilder: semesterDisplayName,
                      onChanged: (v) {
                        setState(() => _resetFromSemester(catalog, v));
                      },
                    ),
                    if (subSegments.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _LabeledDropdown<String>(
                        label: '子科目',
                        value: _subSegment,
                        items: subSegments,
                        onChanged: (v) {
                          setState(() {
                            _subSegment = v;
                            _selectedProductIds.clear();
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '推播單元（複選）',
                      style: HomePageFonts.resolve(const TextStyle(
                        fontWeight: AppFonts.weightBold,
                        fontSize: AppFonts.sizeBodySm,
                        color: AppColors.textPrimary,
                      )),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: products
                          .map(
                            (p) => FilterChip(
                              label: Text(
                                p,
                                style: HomePageFonts.resolve(const TextStyle(
                                  fontSize: AppFonts.sizeBodySm,
                                  color: AppColors.textPrimary,
                                )),
                              ),
                              selected: _selectedProductIds.contains(p),
                              onSelected: (_) => _toggleProduct(p),
                              backgroundColor: HomeMeshReferenceColors
                                  .glassFillLight
                                  .withValues(alpha: 0.85),
                              selectedColor: HomeMeshReferenceColors.lavender
                                  .withValues(alpha: 0.38),
                              checkmarkColor: HomeMeshReferenceColors.accentPurple,
                              side: BorderSide(
                                color: HomeMeshReferenceColors.glassBorderWhite,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              _BannerGlassSection(
                title: '時間模式',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RadioListTile<bool>(
                      title: Text(
                        '預設（建議）',
                        style: HomePageFonts.resolve(const TextStyle(
                          fontSize: AppFonts.sizeBodyLg,
                          color: AppColors.textPrimary,
                          fontWeight: AppFonts.weightRegular,
                        )),
                      ),
                      value: true,
                      groupValue: _useDefaultSlots,
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _useDefaultSlots = v);
                      },
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.textPrimary,
                    ),
                    if (_useDefaultSlots) ...[
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                        childAspectRatio: 2.8,
                        children:
                            List.generate(kDefaultSlotRanges.length, (i) {
                          final selected = _selectedSlotIndices.contains(i);
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _toggleSlot(i),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSm,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: selected
                                      ? HomeMeshReferenceColors.lavender
                                          .withValues(alpha: 0.28)
                                      : HomeMeshReferenceColors.glassFillLight
                                          .withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSm,
                                  ),
                                  border: Border.all(
                                    color: selected
                                        ? HomeMeshReferenceColors.accentPurple
                                            .withValues(alpha: 0.45)
                                        : HomeMeshReferenceColors
                                            .glassBorderWhite,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      selected
                                          ? Icons.check_circle_rounded
                                          : Icons.circle_outlined,
                                      size: 18,
                                      color: selected
                                          ? HomeMeshReferenceColors.accentPurple
                                          : AppColors.textTertiary,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        _formatSlotRange(i),
                                        style: HomePageFonts.resolve(TextStyle(
                                          fontSize: AppFonts.sizeBodySm,
                                          fontWeight: selected
                                              ? AppFonts.weightSemibold
                                              : AppFonts.weightRegular,
                                          color: AppColors.textPrimary,
                                        )),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                    RadioListTile<bool>(
                      title: Text(
                        '自訂時段',
                        style: HomePageFonts.resolve(const TextStyle(
                          fontSize: AppFonts.sizeBodyLg,
                          color: AppColors.textPrimary,
                          fontWeight: AppFonts.weightRegular,
                        )),
                      ),
                      value: false,
                      groupValue: _useDefaultSlots,
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _useDefaultSlots = v);
                      },
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.textPrimary,
                    ),
                    if (!_useDefaultSlots) ...[
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (var i = 0; i < _customTimes.length; i++)
                            InputChip(
                              label: Text(
                                '${_customTimes[i].hour.toString().padLeft(2, '0')}:'
                                '${_customTimes[i].minute.toString().padLeft(2, '0')}',
                                style: HomePageFonts.resolve(const TextStyle(
                                  fontSize: AppFonts.sizeBodySm,
                                  color: AppColors.textPrimary,
                                )),
                              ),
                              deleteIconColor: AppColors.textSecondary,
                              backgroundColor: HomeMeshReferenceColors
                                  .glassFillLight
                                  .withValues(alpha: 0.85),
                              side: BorderSide(
                                color:
                                    HomeMeshReferenceColors.glassBorderWhite,
                              ),
                              onDeleted: () => setState(
                                () => _customTimes.removeAt(i),
                              ),
                            ),
                          ActionChip(
                            avatar: const Icon(
                              Icons.add,
                              size: 18,
                              color: AppColors.textPrimary,
                            ),
                            label: Text(
                              '新增時段',
                              style: HomePageFonts.resolve(const TextStyle(
                                fontSize: AppFonts.sizeBodySm,
                                color: AppColors.textPrimary,
                              )),
                            ),
                            backgroundColor: HomeMeshReferenceColors
                                .glassFillLight
                                .withValues(alpha: 0.85),
                            side: BorderSide(
                              color: HomeMeshReferenceColors.glassBorderWhite,
                            ),
                            onPressed: _pickCustomTime,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              _BannerGlassSection(
                title: '頻率',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      // ignore: deprecated_member_use — 需同步頻率與排程
                      value: _frequency,
                      items: const [1, 3, 5, 10]
                          .map(
                            (n) => DropdownMenuItem<int>(
                              value: n,
                              child: Text('每天 $n 則'),
                            ),
                          )
                          .toList(),
                      decoration: _glassInputDecoration(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _frequency = v);
                      },
                    ),
                    if (overGlobal) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1)
                              .withValues(alpha: 0.92),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(
                            color: const Color(0xFFFFC107)
                                .withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.amber.shade800,
                              size: 22,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                '總頻率可能超過全域上限。\n'
                                '所選 ${_selectedProductIds.length} 個產品 × 每天 $_frequency 則 '
                                '≈ 每天 $_totalDailyEstimate 則（建議總量勿超過 20），部分通知可能無法送達。',
                                style: HomePageFonts.resolve(const TextStyle(
                                  fontSize: AppFonts.sizeBodySm,
                                  height: AppFonts.lineHeightRelaxed,
                                  color: AppColors.textPrimary,
                                )),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _onDisable,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(
                          color:
                              AppColors.textPrimary.withValues(alpha: 0.22),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.compact,
                        ),
                        textStyle: HomePageFonts.resolve(const TextStyle(
                          fontSize: AppFonts.sizeBodySm,
                          fontWeight: AppFonts.weightSemibold,
                        )),
                      ),
                      child: const Text('關閉橫幅通知'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _onEnable(catalog),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.compact,
                        ),
                        textStyle: HomePageFonts.resolve(const TextStyle(
                          fontSize: AppFonts.sizeBodySm,
                          fontWeight: AppFonts.weightSemibold,
                          letterSpacing: AppFonts.letterSpacingButton,
                        )),
                      ),
                      child: const Text('開啟橫幅通知'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_activeScheduleSnapshot != null) ...[
                _BannerGlassSection(
                  title: '目前推播設定',
                  subtitle: '已開啟橫幅通知時，會依下列科目、學期、單元與時間頻率推播',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _scheduleSummaryRow(
                        '科目',
                        _activeScheduleSnapshot!.segment.isEmpty
                            ? '—'
                            : _activeScheduleSnapshot!.segment,
                      ),
                      _scheduleSummaryRow(
                        '子科目',
                        _activeScheduleSnapshot!.subSegment.isEmpty
                            ? '—'
                            : _activeScheduleSnapshot!.subSegment,
                      ),
                      _scheduleSummaryRow(
                        '學期',
                        _activeScheduleSnapshot!.semester.isEmpty
                            ? '—'
                            : semesterDisplayName(
                                _activeScheduleSnapshot!.semester,
                              ),
                      ),
                      _scheduleSummaryRow(
                        '單元',
                        _activeScheduleSnapshot!.productIds.isEmpty
                            ? '—'
                            : _activeScheduleSnapshot!.productIds.join('、'),
                      ),
                      _scheduleSummaryRow(
                        '時間與頻率',
                        _describeActiveSchedule(_activeScheduleSnapshot!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              _BannerGlassSection(
                title: '橫幅通知功能說明',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bannerHelpLine(
                      '推播內容依你所選的科目、年級與複選單元，從教材橫幅資料中輪流取用；通知標題為該則推播標題，內文為對應重點內容。',
                    ),
                    _bannerChineseExampleBlock(catalog.chineseExampleItem),
                    _bannerHelpLine(
                      '橫幅顯示：為配合系統通知列版面，單則內文超過約 '
                      '${BannerNotificationService.maxNotificationBodyLength} '
                      '字時會截斷並以省略號結尾（與範例區「橫幅內文預覽」相同規則）；若需閱讀全文，請在學習／教材流程中查看。',
                    ),
                    _bannerHelpLine(
                      '時間與頻率：「預設時段」或「自訂時段」決定每天大約在哪些時間觸發；「頻率」決定每天要排幾則會重複出現的推播。',
                    ),
                    _bannerHelpLine(
                      '「開啟橫幅通知」會請求通知權限並建立每日本地排程（目前以 iOS 為主）；「關閉橫幅通知」會取消已排程並停止推播。',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: HomeMeshReferenceColors.lavender,
          ),
        ),
        error: (e, _) => Center(
          child: Text(
            '載入失敗：$e',
            style: HomePageFonts.resolve(const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFonts.sizeBodyLg,
            )),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

InputDecoration _glassInputDecoration() {
  final r = BorderRadius.circular(AppSpacing.radiusSm);
  final side = BorderSide(color: HomeMeshReferenceColors.glassBorderWhite);
  return InputDecoration(
    filled: true,
    fillColor: HomeMeshReferenceColors.glassFillLight.withValues(alpha: 0.9),
    border: OutlineInputBorder(borderRadius: r, borderSide: side),
    enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: side),
    focusedBorder: OutlineInputBorder(
      borderRadius: r,
      borderSide: BorderSide(
        color: AppColors.textPrimary.withValues(alpha: 0.35),
        width: 1.2,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.compact,
    ),
  );
}

class _BannerGlassSection extends StatelessWidget {
  const _BannerGlassSection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: GlassCompactCardShell(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: HomePageFonts.resolve(const TextStyle(
                fontSize: AppFonts.sizeTitleSm,
                fontWeight: AppFonts.weightSemibold,
                color: AppColors.textPrimary,
                height: AppFonts.lineHeightTight,
              )),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                style: HomePageFonts.resolve(const TextStyle(
                  fontSize: AppFonts.sizeBodySm,
                  color: AppColors.textSecondary,
                  fontWeight: AppFonts.weightRegular,
                  height: AppFonts.lineHeightBody,
                )),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelBuilder,
  });

  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: HomePageFonts.resolve(const TextStyle(
            fontWeight: AppFonts.weightBold,
            fontSize: AppFonts.sizeBodySm,
            color: AppColors.textPrimary,
          )),
        ),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<T>(
          // ignore: deprecated_member_use — 需依選項同步更新受控值
          value: value != null && items.contains(value) ? value : null,
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text(
                    labelBuilder != null ? labelBuilder!(e) : e.toString(),
                    style: HomePageFonts.resolve(const TextStyle(
                      fontSize: AppFonts.sizeBodySm,
                      color: AppColors.textPrimary,
                    )),
                  ),
                ),
              )
              .toList(),
          decoration: _glassInputDecoration(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
