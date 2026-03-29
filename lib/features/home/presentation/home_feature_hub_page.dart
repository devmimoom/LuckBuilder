import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/home_page_fonts.dart';
import '../../../core/theme/home_mesh_reference_colors.dart';
import '../../../core/utils/app_ux.dart';
import '../../../core/utils/legal_links.dart';
import '../../../core/utils/paywall_gate.dart';
import '../../banner_promotion/presentation/banner_promotion_page.dart';
import '../../exams/presentation/exam_countdown_mini_card.dart';
import '../../exams/presentation/exam_countdown_page.dart';
import '../../exams/providers/exam_countdown_provider.dart';
import '../../insights/presentation/knowledge_graph_page.dart';
import '../../insights/presentation/learning_dashboard_page.dart';
import '../../practice/presentation/mock_exam_page.dart';
import '../../practice/presentation/similar_practice_page.dart';
import '../../review/presentation/review_page.dart';
import '../../review/providers/review_provider.dart';
import '../../subscription/providers/feature_trial_provider.dart';
import '../../tasks/presentation/tasks_page.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../../settings/providers/user_display_name_provider.dart';
import '../../settings/providers/user_encouragement_message_provider.dart';
import '../../settings/providers/user_profile_photo_provider.dart';

const _compactCardTitleShadows = [
  Shadow(color: Color(0x42000000), offset: Offset(0, 1), blurRadius: 3),
];

const _compactCardSubtitleShadows = [
  Shadow(color: Color(0x38000000), offset: Offset(0, 0.5), blurRadius: 2),
];

class HomeFeatureHubPage extends ConsumerWidget {
  const HomeFeatureHubPage({
    super.key,
    required this.onOpenMistakesTab,
  });

  final VoidCallback onOpenMistakesTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewSummaryAsync = ref.watch(reviewSummaryProvider);
    final tasksAsync = ref.watch(todayTasksProvider);
    final examsAsync = ref.watch(examCountdownProvider);
    final userDisplayName =
        userDisplayNameForGreeting(ref.watch(userDisplayNameProvider));
    final photoPath = ref.watch(userProfilePhotoPathProvider);
    final encouragementMessage = ref.watch(userEncouragementMessageProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hi, $userDisplayName',
                      style: HomePageFonts.resolve(const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: AppFonts.sizeDisplayLg,
                        fontWeight: AppFonts.weightSemibold,
                        height: AppFonts.lineHeightTight,
                      )),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _buildGreetingAvatar(
                    userDisplayName: userDisplayName,
                    photoPath: photoPath,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4),
              child: Text(
                encouragementMessage,
                style: HomePageFonts.resolve(const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFonts.sizeBodyLg,
                  fontWeight: AppFonts.weightRegular,
                  height: AppFonts.lineHeightRelaxed,
                )),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildTasksEntry(
              context,
              tasksAsync,
              examsAsync.valueOrNull?.nextExam,
            ),
            const SizedBox(height: AppSpacing.xxl + AppSpacing.md),
            Text(
              '學習工具',
              style: AppFonts.resolve(const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFonts.sizeTitleLg,
                fontWeight: AppFonts.weightSemibold,
                height: AppFonts.lineHeightTight,
              )),
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildCompactActionRow(
              left: _buildCompactCard(
                title: 'AI 相似題練習',
                subtitle: '輸入一題錯題，快速再練同核心觀念',
                fillGradient: HomeCompactCardGradients.similarPractice,
                icon: Icons.edit_note_rounded,
                badgeText: '練習',
                emphasized: true,
                onTap: () async {
                  if (!await PaywallGate.guardFeatureAccess(
                    context,
                    ref,
                    TrialFeature.similarPractice,
                  )) {
                    return;
                  }
                  AppUX.feedbackClick();
                  if (!context.mounted) return;
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
                fillGradient: HomeCompactCardGradients.mockExam,
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
                fillGradient: HomeCompactCardGradients.knowledgeGraph,
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
                fillGradient: HomeCompactCardGradients.learningDashboard,
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
            _buildBannerPromotionEntry(context, ref),
            const SizedBox(height: 60),
            _buildLegalFooterLinks(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalFooterLinks(BuildContext context) {
    const linkColor = AppColors.textTertiary;
    final linkStyle = HomePageFonts.resolve(
      TextStyle(
        color: linkColor,
        fontSize: AppFonts.sizeBodySm,
        fontWeight: AppFonts.weightRegular,
        decoration: TextDecoration.underline,
        decorationColor: linkColor.withValues(alpha: 0.55),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          TextButton(
            onPressed: () => _launchLegalUri(
              context,
              LegalLinks.privacyPolicy,
              '無法開啟隱私權政策連結',
            ),
            style: TextButton.styleFrom(
              foregroundColor: linkColor,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('隱私權政策', style: linkStyle),
          ),
          Text(
            '·',
            style: HomePageFonts.resolve(
              TextStyle(
                color: AppColors.textTertiary.withValues(alpha: 0.55),
                fontSize: AppFonts.sizeBodySm,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _launchLegalUri(
              context,
              LegalLinks.termsOfService,
              '無法開啟使用條款連結',
            ),
            style: TextButton.styleFrom(
              foregroundColor: linkColor,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('使用條款', style: linkStyle),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerPromotionEntry(BuildContext context, WidgetRef ref) {
    return _buildCompactCard(
      title: '學習橫幅推播',
      subtitle: '依序選科目、年級、單元，把重點送到通知橫幅',
      fillGradient: HomeCompactCardGradients.knowledgeGraph,
      icon: Icons.notifications_active_rounded,
      badgeText: '推播',
      onTap: () async {
        if (!await PaywallGate.guardFeatureAccess(
          context,
          ref,
          TrialFeature.bannerPromotion,
        )) {
          return;
        }
        AppUX.feedbackClick();
        if (!context.mounted) return;
        Navigator.of(context).push(
          AppUX.fadeRoute(const BannerPromotionPage()),
        );
      },
    );
  }

  Widget _buildGreetingAvatar({
    required String userDisplayName,
    required String? photoPath,
  }) {
    final hasPhoto = photoPath != null && photoPath.isNotEmpty;
    final displayInitial = userDisplayName.trim().isEmpty
        ? 'A'
        : userDisplayName.trim().characters.first.toUpperCase();
    const avatarSize = 72.0;
    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFEAF1FF),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? Image.file(
              File(photoPath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  displayInitial,
                  style: HomePageFonts.resolve(const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppFonts.sizeHeading,
                    fontWeight: AppFonts.weightSemibold,
                  )),
                ),
              ),
            )
          : Center(
              child: Text(
                displayInitial,
                style: HomePageFonts.resolve(const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppFonts.sizeHeading,
                  fontWeight: AppFonts.weightSemibold,
                )),
              ),
            ),
    );
  }

  Widget _buildTasksEntry(
    BuildContext context,
    AsyncValue<DailyTasksData> tasksAsync,
    ExamCountdown? nextExam,
  ) {
    final topRightOverlay = nextExam != null
        ? ExamCountdownMiniHeroCard(exam: nextExam)
        : null;

    return tasksAsync.when(
      data: (tasksData) => _buildCompactCard(
        title: '今日任務',
        subtitle:
            '${tasksData.completedCount}/${tasksData.tasks.length} 完成・每天一小步，累積就是大進步',
        fillGradient: HomeCompactCardGradients.learningDashboard,
        icon: Icons.checklist_rounded,
        badgeText: '${tasksData.completedCount}/${tasksData.tasks.length}',
        square: true,
        bottomAssetPath: 'assets/home.png',
        overflowBottomAsset: true,
        useHeaderText: true,
        topRightOverlay: topRightOverlay,
        onTap: () {
          AppUX.feedbackClick();
          Navigator.of(context).push(
            AppUX.fadeRoute(const TasksPage()),
          );
        },
      ),
      loading: () => _buildCompactCard(
        title: '今日任務',
        subtitle: '正在整理今天的任務...',
        fillGradient: HomeCompactCardGradients.learningDashboard,
        icon: Icons.checklist_rounded,
        badgeText: '整理中',
        square: true,
        bottomAssetPath: 'assets/home.png',
        overflowBottomAsset: true,
        useHeaderText: true,
        topRightOverlay: topRightOverlay,
        onTap: null,
      ),
      error: (_, __) => _buildCompactCard(
        title: '今日任務',
        subtitle: '點擊查看今日任務',
        fillGradient: HomeCompactCardGradients.learningDashboard,
        icon: Icons.checklist_rounded,
        badgeText: '查看',
        square: true,
        bottomAssetPath: 'assets/home.png',
        overflowBottomAsset: true,
        useHeaderText: true,
        topRightOverlay: topRightOverlay,
        onTap: () {
          AppUX.feedbackClick();
          Navigator.of(context).push(
            AppUX.fadeRoute(const TasksPage()),
          );
        },
      ),
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

  Widget _buildCompactCard({
    required String title,
    required String subtitle,
    required LinearGradient fillGradient,
    required IconData icon,
    required VoidCallback? onTap,
    String? badgeText,
    bool emphasized = false,
    bool square = false,
    String? bottomAssetPath,
    bool overflowBottomAsset = false,
    bool useHeaderText = false,
    Widget? topRightOverlay,
  }) {
    final minHeight = emphasized ? 158.0 : 138.0;
    const r = HomeMeshReferenceColors.radiusGlassCompact;
    final showInlineBottomAsset =
        bottomAssetPath != null && !overflowBottomAsset;
    final cardBody = Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        showInlineBottomAsset ? 0 : AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (useHeaderText)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HomePageFonts.resolve(const TextStyle(
                          fontSize: AppFonts.sizeTitleLg,
                          fontWeight: AppFonts.weightSemibold,
                          color: HomeMeshReferenceColors.onGradientPrimary,
                          height: AppFonts.lineHeightTight,
                          shadows: _compactCardTitleShadows,
                        )),
                      ),
                      const SizedBox(height: AppSpacing.tight),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: HomePageFonts.resolve(const TextStyle(
                          fontSize: AppFonts.sizeCaption,
                          fontWeight: AppFonts.weightRegular,
                          color: HomeMeshReferenceColors.onGradientSecondary,
                          height: AppFonts.lineHeightBody,
                          shadows: _compactCardSubtitleShadows,
                        )),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: emphasized ? 42 : 40,
                  height: emphasized ? 42 : 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(
                    icon,
                    color: HomeMeshReferenceColors.onGradientPrimary,
                    size: emphasized ? 22 : 20,
                  ),
                ),
              const Spacer(),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  child: Text(
                    badgeText,
                    style: HomePageFonts.badge(
                      HomeMeshReferenceColors.onGradientPrimary,
                    ),
                  ),
                ),
            ],
          ),
          if (!useHeaderText) ...[
            SizedBox(
              height: emphasized ? AppSpacing.lg : AppSpacing.md,
            ),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: HomePageFonts.resolve(TextStyle(
                fontSize:
                    emphasized ? AppFonts.sizeTitleMd : AppFonts.sizeTitleSm,
                fontWeight: AppFonts.weightSemibold,
                color: HomeMeshReferenceColors.onGradientPrimary,
                height: AppFonts.lineHeightTight,
                shadows: _compactCardTitleShadows,
              )),
            ),
            const SizedBox(height: AppSpacing.tight),
            Text(
              subtitle,
              maxLines: square ? 5 : 2,
              overflow: TextOverflow.ellipsis,
              style: HomePageFonts.resolve(const TextStyle(
                fontSize: AppFonts.sizeCaption,
                fontWeight: AppFonts.weightRegular,
                color: HomeMeshReferenceColors.onGradientSecondary,
                height: AppFonts.lineHeightBody,
                shadows: _compactCardSubtitleShadows,
              )),
            ),
          ],
          if (showInlineBottomAsset) ...[
            const Spacer(),
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: double.infinity,
                height: 120,
                child: Image.asset(
                  bottomAssetPath,
                  alignment: Alignment.bottomCenter,
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final baseCard = ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(r),
          splashColor: Colors.white.withValues(alpha: 0.22),
          highlightColor: Colors.white.withValues(alpha: 0.12),
          child: Ink(
            decoration: BoxDecoration(
              gradient: fillGradient,
              borderRadius: BorderRadius.circular(r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: emphasized ? 0.24 : 0.2),
                  offset: const Offset(0, 8),
                  blurRadius: emphasized ? 22 : 16,
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  square
                      ? AspectRatio(aspectRatio: 1, child: cardBody)
                      : cardBody,
                  if (topRightOverlay != null)
                    Positioned.fill(
                      child: Align(
                        // 靠右上、略偏左；比先前再往上一些
                        alignment: const Alignment(0.86, -0.58),
                        child: topRightOverlay,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (bottomAssetPath != null && overflowBottomAsset) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          baseCard,
          Positioned(
            left: 0,
            right: 0,
            bottom: -22,
            child: IgnorePointer(
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 1,
                  child: Image.asset(
                    bottomAssetPath,
                    alignment: Alignment.bottomCenter,
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return baseCard;
  }

  Widget _buildReviewCompactCard(
    BuildContext context,
    AsyncValue<ReviewSummary> reviewSummaryAsync,
  ) {
    return reviewSummaryAsync.when(
      data: (summary) => _buildCompactCard(
        title: '錯題複習',
        subtitle: summary.dueCount == 0 ? '進度有跟上，現在可以回頭看最近收藏' : '把昨天的錯，變成今天真的會',
        fillGradient: HomeCompactCardGradients.review,
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
        fillGradient: HomeCompactCardGradients.review,
        icon: Icons.refresh_rounded,
        badgeText: '整理中',
        emphasized: true,
        onTap: null,
      ),
      error: (_, __) => _buildCompactCard(
        title: '錯題複習',
        subtitle: '先去錯題本看看最近收藏的題目',
        fillGradient: HomeCompactCardGradients.review,
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
          fillGradient: HomeCompactCardGradients.examCountdown,
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
        fillGradient: HomeCompactCardGradients.examCountdown,
        icon: Icons.event_available_rounded,
        badgeText: '整理中',
        onTap: null,
      ),
      error: (_, __) => _buildCompactCard(
        title: '考試倒數',
        subtitle: '點一下設定段考、學測、會考或自訂日期',
        fillGradient: HomeCompactCardGradients.examCountdown,
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
}

Future<void> _launchLegalUri(
  BuildContext context,
  Uri uri,
  String errorMessage,
) async {
  AppUX.feedbackClick();
  final launched =
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    AppUX.showSnackBar(context, errorMessage, isError: true);
  }
}
