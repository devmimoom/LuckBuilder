import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/image_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_ux.dart';
import '../../camera/presentation/multi_crop_screen.dart';
import '../../review/presentation/review_page.dart';
import '../../review/providers/review_provider.dart';
import '../providers/tasks_provider.dart';

class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(todayTasksProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('今日任務'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: tasksAsync.when(
        data: (tasksData) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSummaryCard(tasksData),
            const SizedBox(height: 20),
            ...tasksData.tasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今天照著做就進步',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '已完成 ${tasksData.completedCount}/${tasksData.tasks.length}，進度 $percent%',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: tasksData.completionRate,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '連續完成 ${tasksData.streakDays} 天',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, WidgetRef ref, DailyTask task) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
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
          const SizedBox(height: 8),
          Text(
            task.subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '約 ${task.estimateMinutes} 分鐘',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => _handleTaskAction(context, ref, task),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: Colors.white,
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
