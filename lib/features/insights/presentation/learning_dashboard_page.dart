import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/premium_card.dart';
import '../providers/learning_insights_provider.dart';

class LearningDashboardPage extends ConsumerWidget {
  const LearningDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(learningInsightsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('學習儀表板'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: insightsAsync.when(
        data: (insights) {
          if (insights.totalMistakes == 0) {
            return const _EmptyDashboard();
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _OverviewCard(insights: insights),
              const SizedBox(height: 20),
              const _SectionTitle('關鍵指標'),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final style =
                      _MetricGridStyle.fromWidth(constraints.maxWidth);
                  final itemWidth = (constraints.maxWidth -
                          (style.columns - 1) * style.spacing) /
                      style.columns;

                  final metrics = [
                    _MetricCard(
                      label: '累積錯題',
                      value: '${insights.totalMistakes}',
                      hint: '你已經整理出的題目',
                      color: const Color(0xFF007AFF),
                      style: style,
                    ),
                    _MetricCard(
                      label: '待複習',
                      value: '${insights.dueCount}',
                      hint: '現在最該回頭看的題目',
                      color: const Color(0xFF7B61FF),
                      style: style,
                    ),
                    _MetricCard(
                      label: '已掌握',
                      value: '${insights.masteredCount}',
                      hint: '掌握度 2 以上',
                      color: const Color(0xFF22C55E),
                      style: style,
                    ),
                    _MetricCard(
                      label: '本週新增',
                      value: '${insights.newThisWeekCount}',
                      hint: '最近 7 天加入的題目',
                      color: const Color(0xFFFF8A00),
                      style: style,
                    ),
                  ];

                  return Wrap(
                    spacing: style.spacing,
                    runSpacing: style.spacing,
                    children: metrics
                        .map(
                          (card) => SizedBox(
                            width: itemWidth,
                            height: style.cardHeight,
                            child: card,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              const _SectionTitle('最近 7 天錯題整理'),
              const SizedBox(height: 12),
              _RecentActivityCard(activity: insights.recentActivity),
              const SizedBox(height: 24),
              const _SectionTitle('掌握分布'),
              const SizedBox(height: 12),
              _MasteryDistributionCard(insights: insights),
              const SizedBox(height: 24),
              const _SectionTitle('科目分布'),
              const SizedBox(height: 12),
              ...insights.subjectInsights.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SubjectInsightTile(
                      insight: item,
                      maxCount: insights.subjectInsights.first.totalCount,
                      totalMistakes: insights.totalMistakes,
                    ),
                  )),
              const SizedBox(height: 24),
              const _SectionTitle('目前最需要補強'),
              const SizedBox(height: 12),
              if (insights.weakCategories.isEmpty)
                const PremiumCard(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      '目前還沒有足夠資料判斷弱點，先持續累積錯題吧。',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ...insights.weakCategories.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _WeakCategoryTile(insight: item),
                    )),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('載入學習統計失敗：$error'),
          ),
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.insights});

  final LearningInsightsData insights;

  @override
  Widget build(BuildContext context) {
    final masteredRate = insights.totalMistakes == 0
        ? 0
        : insights.masteredCount / insights.totalMistakes;
    final averageMasteryText = insights.averageMastery >= 1.6
        ? '整體狀態很穩'
        : insights.averageMastery >= 0.9
            ? '正在持續進步中'
            : '建議先專注清掉待複習';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF374151)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '你的學習全貌',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '已掌握 ${(masteredRate * 100).round()}% 的錯題，$averageMasteryText。',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _OverviewPill(
                label: '掌握中',
                value: '${insights.learningCount} 題',
              ),
              const SizedBox(width: 10),
              _OverviewPill(
                label: '平均掌握',
                value: insights.averageMastery.toStringAsFixed(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewPill extends StatelessWidget {
  const _OverviewPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
    required this.style,
  });

  final String label;
  final String value;
  final String hint;
  final Color color;
  final _MetricGridStyle style;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: style.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: style.labelFontSize,
            ),
          ),
          SizedBox(height: style.gap),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: style.valueFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: style.gap),
          Text(
            hint,
            maxLines: style.hintMaxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: style.hintFontSize,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGridStyle {
  const _MetricGridStyle({
    required this.columns,
    required this.cardHeight,
    required this.cardPadding,
    required this.labelFontSize,
    required this.valueFontSize,
    required this.hintFontSize,
    required this.hintMaxLines,
  });

  final int columns;
  final double cardHeight;
  final EdgeInsetsGeometry cardPadding;
  final double labelFontSize;
  final double valueFontSize;
  final double hintFontSize;
  final int hintMaxLines;
  final double spacing = 12;
  final double gap = 4;

  factory _MetricGridStyle.fromWidth(double width) {
    if (width < 420) {
      return const _MetricGridStyle(
        columns: 1,
        cardHeight: 110,
        cardPadding: EdgeInsets.fromLTRB(14, 10, 14, 10),
        labelFontSize: 12,
        valueFontSize: 28,
        hintFontSize: 11,
        hintMaxLines: 2,
      );
    }

    if (width < 760) {
      return const _MetricGridStyle(
        columns: 2,
        cardHeight: 124,
        cardPadding: EdgeInsets.fromLTRB(12, 10, 12, 10),
        labelFontSize: 12,
        valueFontSize: 26,
        hintFontSize: 11,
        hintMaxLines: 1,
      );
    }

    return const _MetricGridStyle(
      columns: 4,
      cardHeight: 128,
      cardPadding: EdgeInsets.fromLTRB(14, 10, 14, 10),
      labelFontSize: 13,
      valueFontSize: 30,
      hintFontSize: 12,
      hintMaxLines: 1,
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.activity});

  final List<DailyMistakeActivity> activity;

  @override
  Widget build(BuildContext context) {
    final maxCount = activity.fold<int>(0, (max, item) {
      return item.count > max ? item.count : max;
    });
    final safeMax = math.max(1, maxCount);
    final totalCount = activity.fold<int>(0, (sum, item) => sum + item.count);
    final avgCount = totalCount / activity.length;
    final activeDays = activity.where((item) => item.count > 0).length;
    final firstHalf =
        activity.take(3).fold<int>(0, (sum, item) => sum + item.count);
    final lastHalf =
        activity.skip(4).fold<int>(0, (sum, item) => sum + item.count);
    final trendLabel = lastHalf >= firstHalf ? '趨勢上升' : '趨勢下降';
    final trendColor = lastHalf >= firstHalf
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);

    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
        child: Column(
          children: [
            Row(
              children: [
                _ChartMetaPill(
                  label: '總整理',
                  value: '$totalCount 題',
                  color: const Color(0xFF4F46E5),
                ),
                const SizedBox(width: 8),
                _ChartMetaPill(
                  label: '活躍天數',
                  value: '$activeDays / 7',
                  color: const Color(0xFF0EA5E9),
                ),
                const SizedBox(width: 8),
                _ChartMetaPill(
                  label: trendLabel,
                  value: '',
                  color: trendColor,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 180,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const chartTop = 10.0;
                  const chartBottom = 36.0;
                  final chartHeight =
                      constraints.maxHeight - chartTop - chartBottom;
                  final avgTop = chartTop +
                      chartHeight -
                      (avgCount / safeMax * chartHeight);
                  final stepX = constraints.maxWidth / activity.length;
                  final points = <Offset>[];
                  for (var index = 0; index < activity.length; index++) {
                    final item = activity[index];
                    final ratio = item.count / safeMax;
                    points.add(
                      Offset(
                        stepX * index + (stepX / 2),
                        chartTop + chartHeight - (ratio * chartHeight),
                      ),
                    );
                  }

                  return Stack(
                    children: [
                      Positioned(
                        top: chartTop,
                        left: 0,
                        right: 0,
                        bottom: chartBottom,
                        child: CustomPaint(
                          painter: _ChartGridPainter(),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: avgTop.clamp(chartTop, chartTop + chartHeight),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '平均 ${avgCount.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: chartTop,
                        left: 0,
                        right: 0,
                        bottom: chartBottom,
                        child: CustomPaint(
                          painter: _ChartLinePainter(points: points),
                        ),
                      ),
                      Positioned(
                        top: chartTop,
                        left: 0,
                        right: 0,
                        bottom: chartBottom,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: activity.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final ratio = item.count / safeMax;
                            final maxBarHeight =
                                (chartHeight - 24).clamp(14.0, chartHeight);
                            final barHeight =
                                (14 + (ratio * (maxBarHeight - 14)))
                                    .clamp(14.0, maxBarHeight);
                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${item.count}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 250),
                                          height: barHeight,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                const Color(0xFF818CF8),
                                                index == activity.length - 1
                                                    ? const Color(0xFF4F46E5)
                                                    : const Color(0xFF6366F1),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Row(
                          children: activity.map((item) {
                            return Expanded(
                              child: Text(
                                DateFormat('E').format(item.date),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '看你最近是不是有穩定整理錯題，抓出最容易斷掉的日子。',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MasteryDistributionCard extends StatelessWidget {
  const _MasteryDistributionCard({required this.insights});

  final LearningInsightsData insights;

  @override
  Widget build(BuildContext context) {
    final retryCount = insights.totalMistakes -
        insights.masteredCount -
        insights.learningCount;
    final retryRatio =
        insights.totalMistakes == 0 ? 0 : retryCount / insights.totalMistakes;
    final learningRatio = insights.totalMistakes == 0
        ? 0
        : insights.learningCount / insights.totalMistakes;
    final masteredRatio = insights.totalMistakes == 0
        ? 0
        : insights.masteredCount / insights.totalMistakes;

    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    if (retryRatio > 0)
                      Expanded(
                        flex: (retryRatio * 1000).round(),
                        child: const ColoredBox(color: Color(0xFFE11D48)),
                      ),
                    if (learningRatio > 0)
                      Expanded(
                        flex: (learningRatio * 1000).round(),
                        child: const ColoredBox(color: Color(0xFFF59E0B)),
                      ),
                    if (masteredRatio > 0)
                      Expanded(
                        flex: (masteredRatio * 1000).round(),
                        child: const ColoredBox(color: Color(0xFF22C55E)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _MasteryRow(
              label: '需要重學',
              count: retryCount,
              total: insights.totalMistakes,
              color: const Color(0xFFE11D48),
            ),
            const SizedBox(height: 12),
            _MasteryRow(
              label: '掌握中',
              count: insights.learningCount,
              total: insights.totalMistakes,
              color: const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 12),
            _MasteryRow(
              label: '已掌握',
              count: insights.masteredCount,
              total: insights.totalMistakes,
              color: const Color(0xFF22C55E),
            ),
          ],
        ),
      ),
    );
  }
}

class _MasteryRow extends StatelessWidget {
  const _MasteryRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : count / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '$count 題 (${(progress * 100).round()}%)',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _SubjectInsightTile extends StatelessWidget {
  const _SubjectInsightTile({
    required this.insight,
    required this.maxCount,
    required this.totalMistakes,
  });

  final SubjectInsight insight;
  final int maxCount;
  final int totalMistakes;

  @override
  Widget build(BuildContext context) {
    final widthRatio = maxCount == 0 ? 0.0 : insight.totalCount / maxCount;
    final share = totalMistakes == 0 ? 0.0 : insight.totalCount / totalMistakes;
    final dueRatio =
        insight.totalCount == 0 ? 0.0 : insight.dueCount / insight.totalCount;

    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  insight.subject,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${insight.totalCount} 題 (${(share * 100).round()}%)',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: widthRatio,
                minHeight: 10,
                backgroundColor: AppColors.border,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '待複習 ${insight.dueCount} 題 (${(dueRatio * 100).round()}%)・已掌握 ${(insight.masteredRate * 100).round()}%',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartMetaPill extends StatelessWidget {
  const _ChartMetaPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (value.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChartGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChartLinePainter extends CustomPainter {
  const _ChartLinePainter({required this.points});

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final linePaint = Paint()
      ..color = const Color(0xFF4338CA).withValues(alpha: 0.9)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()
      ..color = const Color(0xFF4338CA)
      ..style = PaintingStyle.fill;
    for (final point in points) {
      canvas.drawCircle(point, 2.8, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartLinePainter oldDelegate) {
    if (oldDelegate.points.length != points.length) return true;
    for (var i = 0; i < points.length; i++) {
      if (oldDelegate.points[i] != points[i]) return true;
    }
    return false;
  }
}

class _WeakCategoryTile extends StatelessWidget {
  const _WeakCategoryTile({required this.insight});

  final CategoryWeaknessInsight insight;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.track_changes_rounded,
                color: Color(0xFFE11D48),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${insight.subject}・${insight.category}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '共 ${insight.totalCount} 題，待複習 ${insight.dueCount} 題，平均掌握 ${insight.averageMastery.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 64,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: 16),
            Text(
              '還沒有足夠的學習資料',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '先拍幾題、存進錯題本後，這裡就會自動幫你整理學習趨勢與弱點。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
