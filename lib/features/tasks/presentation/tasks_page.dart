import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/image_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/home_mesh_reference_colors.dart';
import '../../../core/theme/home_page_fonts.dart';
import '../../../core/utils/app_ux.dart';
import '../../../core/utils/paywall_gate.dart';
import '../../../core/widgets/glass_compact_card_shell.dart';
import '../../camera/presentation/multi_crop_screen.dart';
import '../../review/presentation/review_page.dart';
import '../../review/providers/review_provider.dart';
import '../../subscription/providers/feature_trial_provider.dart';
import '../providers/tasks_provider.dart';

class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(todayTasksProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('今日任務'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: tasksAsync.when(
        data: (tasksData) => ListView(
          padding: AppSpacing.screenPadding,
          children: [
            _buildSummaryCard(tasksData),
            const SizedBox(height: AppSpacing.lg),
            ...tasksData.tasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.compact),
                child: _buildTaskCard(context, ref, task),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('載入今日任務失敗：$error')),
      ),
    );
  }

  Widget _buildSummaryCard(DailyTasksData tasksData) {
    final percent = (tasksData.completionRate * 100).round();

    return Container(
      decoration: BoxDecoration(
        gradient: HomeCompactCardGradients.learningDashboard,
        borderRadius:
            BorderRadius.circular(HomeMeshReferenceColors.radiusGlassCompact),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '每天照著做，進步看得見',
            style: HomePageFonts.resolve(const TextStyle(
              color: Colors.white,
              fontSize: AppFonts.sizeTitleLg,
              fontWeight: AppFonts.weightSemibold,
            )),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '已完成 ${tasksData.completedCount}/${tasksData.tasks.length}，進度 $percent%',
            style: HomePageFonts.resolve(TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: AppFonts.sizeBodySm,
              fontWeight: AppFonts.weightRegular,
            )),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: tasksData.completionRate,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '連續完成 ${tasksData.streakDays} 天',
            style: HomePageFonts.resolve(const TextStyle(
              color: Colors.white,
              fontSize: AppFonts.sizeCaption,
              fontWeight: AppFonts.weightSemibold,
            )),
          ),
          if (tasksData.completedCount == tasksData.tasks.length &&
              tasksData.tasks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '今天的任務全部完成了，你真的很棒！',
              style: HomePageFonts.resolve(TextStyle(
                color: Colors.white.withValues(alpha: 0.74),
                fontSize: AppFonts.sizeCaption,
                fontWeight: AppFonts.weightRegular,
                height: AppFonts.lineHeightBody,
              )),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, WidgetRef ref, DailyTask task) {
    return GlassCompactCardShell(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: HomePageFonts.resolve(const TextStyle(
                    fontSize: AppFonts.sizeTitleSm,
                    fontWeight: AppFonts.weightSemibold,
                    color: AppColors.textPrimary,
                    height: AppFonts.lineHeightTight,
                  )),
                ),
              ),
              Icon(
                task.isCompleted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: task.isCompleted
                    ? const Color(0xFF2E7D32)
                    : AppColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            task.subtitle,
            style: HomePageFonts.resolve(const TextStyle(
              fontSize: AppFonts.sizeBodySm,
              color: AppColors.textSecondary,
              fontWeight: AppFonts.weightRegular,
              height: AppFonts.lineHeightBody,
            )),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: HomeMeshReferenceColors.glassFillLight,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: HomeMeshReferenceColors.glassBorderWhite),
                ),
                child: Text(
                  '約 ${task.estimateMinutes} 分鐘',
                  style: HomePageFonts.resolve(const TextStyle(
                    fontSize: AppFonts.sizeCaption,
                    color: AppColors.textSecondary,
                    fontWeight: AppFonts.weightSemibold,
                  )),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => _handleTaskAction(context, ref, task),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.inset,
                    vertical: AppSpacing.compact,
                  ),
                  textStyle: HomePageFonts.resolve(const TextStyle(
                    fontSize: AppFonts.sizeBodySm,
                    fontWeight: AppFonts.weightSemibold,
                    letterSpacing: AppFonts.letterSpacingButton,
                  )),
                ),
                child: Text(task.isCompleted ? '再做一次' : task.ctaLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleTaskAction(
    BuildContext context,
    WidgetRef ref,
    DailyTask task,
  ) async {
    AppUX.feedbackClick();

    switch (task.actionType) {
      case TaskActionType.dueReview:
        await Navigator.of(context).push(
          AppUX.fadeRoute(const ReviewPage(initialMode: ReviewMode.standard)),
        );
        break;
      case TaskActionType.weakSpot:
        await Navigator.of(context).push(
          AppUX.fadeRoute(const ReviewPage(initialMode: ReviewMode.weakSpot)),
        );
        break;
      case TaskActionType.captureNew:
        if (!await PaywallGate.guardFeatureAccess(
          context,
          ref,
          TrialFeature.cameraSolve,
        )) {
          return;
        }
        if (!context.mounted) return;
        final File? image = await ImageService().pickAndCompressImage(
          context,
          fromCamera: true,
        );
        if (image != null && context.mounted) {
          await Navigator.of(context).push(
            AppUX.fadeRoute(MultiCropScreen(imageFile: image)),
          );
        }
        break;
    }

    await ref.read(tasksControllerProvider).markTaskCompleted(task.id);
  }
}
