import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_ux.dart';
import '../../../core/utils/latex_helper.dart';
import '../../../core/services/mistake_share_service.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/database/models/mistake.dart';
import '../../exams/presentation/exam_countdown_page.dart';
import '../../exams/providers/exam_countdown_provider.dart';
import '../../insights/presentation/learning_dashboard_page.dart';
import '../../insights/presentation/knowledge_graph_page.dart';
import '../../camera/presentation/multi_crop_screen.dart';
import '../../mistakes/providers/mistakes_provider.dart';
import '../../practice/presentation/mock_exam_page.dart';
import '../../practice/presentation/similar_practice_page.dart';
import '../../review/presentation/review_page.dart';
import '../../review/providers/review_provider.dart';
import '../../tasks/presentation/tasks_page.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../../../core/services/image_service.dart';

class HomePage extends ConsumerWidget {
  const HomePage({
    super.key,
    required this.onOpenMistakesTab,
  });

  final VoidCallback onOpenMistakesTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewSummaryAsync = ref.watch(reviewSummaryProvider);
    final tasksAsync = ref.watch(todayTasksProvider);
    final mistakesAsync = ref.watch(allMistakesRawProvider);
    final examsAsync = ref.watch(examCountdownProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            _buildWelcomeCard(
                context, reviewSummaryAsync, tasksAsync, examsAsync),
            const SizedBox(height: AppSpacing.xl),
            _buildHeroCard(
              title: '拍題解題',
              subtitle: '卡住就拍，30 秒找到下一步',
              ctaText: '立即開始',
              icon: Icons.camera_alt_rounded,
              onTap: () => _openCamera(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildCompactActionRow(
              left: _buildCompactCard(
                title: 'AI 相似題練習',
                subtitle: '輸入一題錯題，快速再練同核心觀念',
                color: const Color(0xFFFF8A00),
                icon: Icons.edit_note_rounded,
                badgeText: '練習',
                emphasized: true,
                onTap: () {
                  AppUX.feedbackClick();
                  Navigator.of(context).push(
                    AppUX.fadeRoute(const SimilarPracticePage()),
                  );
                },
              ),
              right: _buildReviewCompactCard(context, reviewSummaryAsync),
            ),
            AppSpacing.gapCard,
            _buildCompactActionRow(
              left: _buildExamCompactCard(context, examsAsync),
              right: _buildCompactCard(
                title: '自訂模擬測驗',
                subtitle: '從錯題庫快速組卷，限時練自己的弱點',
                color: const Color(0xFFEF4444),
                icon: Icons.assignment_turned_in_rounded,
                badgeText: '備考',
                onTap: () {
                  AppUX.feedbackClick();
                  Navigator.of(context).push(
                    AppUX.fadeRoute(const MockExamPage()),
                  );
                },
              ),
            ),
            AppSpacing.gapCard,
            _buildCompactActionRow(
              left: _buildCompactCard(
                title: '知識圖譜',
                subtitle: '把分類、章節與核心觀念串起來',
                color: const Color(0xFF8B5CF6),
                icon: Icons.hub_rounded,
                badgeText: '洞察',
                onTap: () {
                  AppUX.feedbackClick();
                  Navigator.of(context).push(
                    AppUX.fadeRoute(const KnowledgeGraphPage()),
                  );
                },
              ),
              right: _buildCompactCard(
                title: '學習儀表板',
                subtitle: '看見最近趨勢、科目分布與弱點章節',
                color: const Color(0xFF10B981),
                icon: Icons.bar_chart_rounded,
                badgeText: '洞察',
                onTap: () {
                  AppUX.feedbackClick();
                  Navigator.of(context).push(
                    AppUX.fadeRoute(const LearningDashboardPage()),
                  );
                },
              ),
            ),
            AppSpacing.gapSection,
            Row(
              children: [
                Text(
                  '最近錯題',
                  style: AppFonts.heading(AppColors.textPrimary),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    AppUX.feedbackClick();
                    onOpenMistakesTab();
                  },
                  child: const Text('看全部'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            mistakesAsync.when(
              data: (mistakes) {
                final latestMistakes = mistakes.take(3).toList();
                if (latestMistakes.isEmpty) {
                  return _buildEmptyRecentCard();
                }

                return Column(
                  children:
                      latestMistakes.map(_buildRecentMistakeCard).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text('載入最近錯題失敗：$error'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(
    BuildContext context,
    AsyncValue<ReviewSummary> reviewSummaryAsync,
    AsyncValue<DailyTasksData> tasksAsync,
    AsyncValue<ExamCountdownData> examsAsync,
  ) {
    return Container(
      padding: AppSpacing.cardPaddingLg,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B6CFF), Color(0xFF8B5CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '嗨，你今天也很棒',
            style: AppFonts.displayMd(Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          reviewSummaryAsync.when(
            data: (summary) => Text(
              summary.dueCount == 0
                  ? '複習進度都跟上了，繼續保持這個節奏！'
                  : '有 ${summary.dueCount} 題在等你複習，一題一題來就好。',
              style: AppFonts.resolve(TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: AppFonts.sizeBodyLg,
                height: AppFonts.lineHeightRelaxed,
              )),
            ),
            loading: () => Text(
              '正在準備今天的學習計畫...',
              style: AppFonts.resolve(TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: AppFonts.sizeBodyLg,
              )),
            ),
            error: (_, __) => Text(
              '今天也是全新的一天，一起加油吧！',
              style: AppFonts.resolve(TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: AppFonts.sizeBodyLg,
              )),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildReviewDesignIntro(),
          const SizedBox(height: AppSpacing.md),
          _buildTasksEntry(context, tasksAsync),
          const SizedBox(height: AppSpacing.md),
          _buildExamPill(context, examsAsync),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.compact,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Text(
              '只要持續記錄，進步就會自然發生 ✨',
              style: AppFonts.resolve(const TextStyle(
                color: Colors.white,
                fontSize: AppFonts.sizeBodySm,
                fontWeight: AppFonts.weightSemibold,
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamPill(
    BuildContext context,
    AsyncValue<ExamCountdownData> examsAsync,
  ) {
    return GestureDetector(
      onTap: () {
        AppUX.feedbackClick();
        Navigator.of(context).push(
          AppUX.fadeRoute(const ExamCountdownPage()),
        );
      },
      child: Container(
        padding: AppSpacing.paddingSnug,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppSpacing.radiusIcon),
              ),
              child:
                  const Icon(Icons.event_repeat_rounded, color: Colors.white),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: examsAsync.when(
                data: (data) {
                  final nextExam = data.nextExam;
                  if (nextExam == null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('考試倒數',
                            style: AppFonts.titleSm(Colors.white)),
                        const SizedBox(height: AppSpacing.xs),
                        Text('還沒設定考試日期，先加上你的下一場目標',
                            style: AppFonts.resolve(TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: AppFonts.sizeBodySm,
                              height: AppFonts.lineHeightBody,
                            ))),
                      ],
                    );
                  }
                  final label = examCountdownLabel(nextExam);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              nextExam.name,
                              style: AppFonts.titleSm(Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.compact, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4D4F),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                            ),
                            child: Text(
                              label,
                              style: AppFonts.resolve(const TextStyle(
                                color: Colors.white,
                                fontSize: AppFonts.sizeCaption,
                                fontWeight: AppFonts.weightBold,
                                letterSpacing: AppFonts.letterSpacingButton,
                              )),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '現在開始安排複習最剛好',
                        style: AppFonts.resolve(TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: AppFonts.sizeBodySm,
                          height: AppFonts.lineHeightBody,
                        )),
                      ),
                    ],
                  );
                },
                loading: () => Text(
                  '正在整理你的考試倒數...',
                  style: AppFonts.resolve(TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: AppFonts.sizeBodySm,
                  )),
                ),
                error: (_, __) => Text(
                  '點擊設定你的下一場考試',
                  style: AppFonts.resolve(TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: AppFonts.sizeBodySm,
                  )),
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksEntry(
    BuildContext context,
    AsyncValue<DailyTasksData> tasksAsync,
  ) {
    return GestureDetector(
      onTap: () {
        AppUX.feedbackClick();
        Navigator.of(context).push(
          AppUX.fadeRoute(const TasksPage()),
        );
      },
      child: Container(
        padding: AppSpacing.paddingSnug,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppSpacing.radiusIcon),
              ),
              child: const Icon(Icons.checklist_rounded, color: Colors.white),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今日任務',
                    style: AppFonts.titleSm(Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  tasksAsync.when(
                    data: (tasksData) => Text(
                      '${tasksData.completedCount}/${tasksData.tasks.length} 完成・每天一小步，累積就是大進步',
                      style: AppFonts.resolve(TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: AppFonts.sizeBodySm,
                        height: AppFonts.lineHeightBody,
                      )),
                    ),
                    loading: () => Text(
                      '正在整理今天的任務...',
                      style: AppFonts.resolve(TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: AppFonts.sizeBodySm,
                      )),
                    ),
                    error: (_, __) => Text(
                      '點擊查看今日任務',
                      style: AppFonts.resolve(TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: AppFonts.sizeBodySm,
                      )),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewDesignIntro() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.trending_up_rounded, color: Colors.white, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            '遺忘曲線複習：系統會依你每次作答表現，安排 1、3、7、14、30 天的複習節點；答得越穩，間隔越長。',
            style: AppFonts.resolve(TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: AppFonts.sizeBodySm,
              height: AppFonts.lineHeightRelaxed,
            )),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactActionRow({
    required Widget left,
    required Widget right,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        AppSpacing.gapCardRow,
        Expanded(child: right),
      ],
    );
  }

  Widget _buildHeroCard({
    required String title,
    required String subtitle,
    required String ctaText,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF007AFF), Color(0xFF0055D4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF007AFF).withValues(alpha: 0.22),
              offset: const Offset(0, 12),
              blurRadius: 32,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xxl,
            AppSpacing.xxl,
            AppSpacing.xl,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.compact,
                        vertical: AppSpacing.tight,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      ),
                      child: Text(
                        '最快開始',
                        style: AppFonts.badge(Colors.white),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.snug),
                    Text(
                      title,
                      style: AppFonts.displayMd(Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      subtitle,
                      style: AppFonts.resolve(TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: AppFonts.sizeBodyLg,
                        height: AppFonts.lineHeightBody,
                      )),
                    ),
                    const SizedBox(height: AppSpacing.snug),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.snug,
                        vertical: AppSpacing.compact,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ctaText,
                            style: AppFonts.resolve(const TextStyle(
                              color: Color(0xFF0055D4),
                              fontSize: AppFonts.sizeBodySm,
                              fontWeight: AppFonts.weightBold,
                              letterSpacing: AppFonts.letterSpacingButton,
                            )),
                          ),
                          const SizedBox(width: AppSpacing.tight),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: Color(0xFF0055D4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(icon, color: Colors.white, size: 36),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCard({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required VoidCallback? onTap,
    String? badgeText,
    bool emphasized = false,
  }) {
    final minHeight = emphasized ? 158.0 : 138.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: emphasized ? 0.05 : 0.03),
              offset: const Offset(0, 6),
              blurRadius: emphasized ? 18 : 12,
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: emphasized ? 42 : 40,
                      height: emphasized ? 42 : 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Icon(icon, color: color, size: emphasized ? 22 : 20),
                    ),
                    const Spacer(),
                    if (badgeText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                        ),
                        child: Text(
                          badgeText,
                          style: AppFonts.badge(color),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: emphasized ? AppSpacing.lg : AppSpacing.md),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.resolve(TextStyle(
                    fontSize: emphasized ? AppFonts.sizeTitleMd : AppFonts.sizeTitleSm,
                    fontWeight: AppFonts.weightSemibold,
                    color: AppColors.textPrimary,
                    height: AppFonts.lineHeightTight,
                  )),
                ),
                const SizedBox(height: AppSpacing.tight),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.resolve(const TextStyle(
                    fontSize: AppFonts.sizeCaption,
                    color: AppColors.textSecondary,
                    height: AppFonts.lineHeightBody,
                  )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCompactCard(
    BuildContext context,
    AsyncValue<ReviewSummary> reviewSummaryAsync,
  ) {
    return reviewSummaryAsync.when(
      data: (summary) => _buildCompactCard(
        title: '錯題複習',
        subtitle: summary.dueCount == 0 ? '進度有跟上，現在可以回頭看最近收藏' : '把昨天的錯，變成今天真的會',
        color: const Color(0xFF7B61FF),
        icon: Icons.refresh_rounded,
        badgeText: summary.dueCount == 0 ? '已跟上' : '${summary.dueCount} 題',
        emphasized: true,
        onTap: () {
          AppUX.feedbackClick();
          Navigator.of(context).push(
            AppUX.fadeRoute(const ReviewPage()),
          );
        },
      ),
      loading: () => _buildCompactCard(
        title: '錯題複習',
        subtitle: '正在整理今天該回頭看的題目',
        color: const Color(0xFF7B61FF),
        icon: Icons.refresh_rounded,
        badgeText: '整理中',
        emphasized: true,
        onTap: null,
      ),
      error: (_, __) => _buildCompactCard(
        title: '錯題複習',
        subtitle: '先去錯題本看看最近收藏的題目',
        color: const Color(0xFF7B61FF),
        icon: Icons.refresh_rounded,
        badgeText: '查看',
        emphasized: true,
        onTap: onOpenMistakesTab,
      ),
    );
  }

  Widget _buildExamCompactCard(
    BuildContext context,
    AsyncValue<ExamCountdownData> examsAsync,
  ) {
    return examsAsync.when(
      data: (data) {
        final nextExam = data.nextExam;
        return _buildCompactCard(
          title: '考試倒數',
          subtitle: nextExam == null
              ? '先設定下一場考試，首頁與 Widget 會同步倒數'
              : '${nextExam.name}，提早把複習節奏排好',
          color: const Color(0xFF6366F1),
          icon: Icons.event_available_rounded,
          badgeText: nextExam == null ? '去設定' : examCountdownLabel(nextExam),
          onTap: () {
            AppUX.feedbackClick();
            Navigator.of(context).push(
              AppUX.fadeRoute(const ExamCountdownPage()),
            );
          },
        );
      },
      loading: () => _buildCompactCard(
        title: '考試倒數',
        subtitle: '正在整理你的下一場重要日期',
        color: const Color(0xFF6366F1),
        icon: Icons.event_available_rounded,
        badgeText: '整理中',
        onTap: null,
      ),
      error: (_, __) => _buildCompactCard(
        title: '考試倒數',
        subtitle: '點一下設定段考、學測、會考或自訂日期',
        color: const Color(0xFF6366F1),
        icon: Icons.event_available_rounded,
        badgeText: '查看',
        onTap: () {
          AppUX.feedbackClick();
          Navigator.of(context).push(
            AppUX.fadeRoute(const ExamCountdownPage()),
          );
        },
      ),
    );
  }

  Widget _buildRecentMistakeCard(Mistake mistake) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.compact),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.tight,
                    runSpacing: AppSpacing.tight,
                    children: [
                      _smallTag(mistake.subject, const Color(0xFFFF9800)),
                      _smallTag(mistake.category, const Color(0xFF2196F3)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    AppUX.feedbackClick();
                    await MistakeShareService.shareMistake(mistake);
                  },
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                  tooltip: '分享錯題',
                  color: AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Row(
              children: [
                if (mistake.imagePath.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                    child: Image.file(
                      File(mistake.imagePath),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: AppColors.surface,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    LatexHelper.toReadableText(
                      mistake.title,
                      fallback: '未命名題目',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.resolve(const TextStyle(
                      fontSize: AppFonts.sizeBodySm,
                      color: AppColors.textPrimary,
                      height: AppFonts.lineHeightBody,
                    )),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRecentCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.inset),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '還沒有錯題，拍一題開始吧！每道錯題都是進步的起點。',
        style: AppFonts.resolve(const TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppFonts.sizeBodySm,
          height: AppFonts.lineHeightRelaxed,
        )),
      ),
    );
  }

  Widget _smallTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(text, style: AppFonts.badge(color)),
    );
  }

  Future<void> _openCamera(BuildContext context) async {
    AppUX.feedbackClick();
    final image = await ImageService().pickAndCompressImage(
      context,
      fromCamera: true,
    );

    if (image != null && context.mounted) {
      Navigator.of(context).push(
        AppUX.fadeRoute(MultiCropScreen(imageFile: image)),
      );
    }
  }
}
