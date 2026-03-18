import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_ux.dart';
import '../../../core/utils/latex_helper.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/database/models/mistake.dart';
import '../../camera/presentation/multi_crop_screen.dart';
import '../../mistakes/providers/mistakes_provider.dart';
import '../../review/presentation/review_page.dart';
import '../../review/providers/review_provider.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../../../core/services/image_service.dart';

class HomePage extends ConsumerWidget {
  const HomePage({
    super.key,
    required this.onOpenTasksTab,
    required this.onOpenMistakesTab,
  });

  final VoidCallback onOpenTasksTab;
  final VoidCallback onOpenMistakesTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewSummaryAsync = ref.watch(reviewSummaryProvider);
    final tasksAsync = ref.watch(todayTasksProvider);
    final mistakesAsync = ref.watch(allMistakesRawProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildTopCard(reviewSummaryAsync),
            const SizedBox(height: 20),
            _buildActionCard(
              title: '拍題解題',
              subtitle: '卡住就拍，30 秒找到下一步',
              trailingText: '立即開始',
              color: const Color(0xFF007AFF),
              icon: Icons.camera_alt_rounded,
              onTap: () => _openCamera(context),
            ),
            const SizedBox(height: 12),
            _buildReviewCard(context, reviewSummaryAsync),
            const SizedBox(height: 12),
            _buildTasksCard(tasksAsync),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  '最近錯題',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
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
            const SizedBox(height: 8),
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
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text('載入最近錯題失敗：$error'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCard(AsyncValue<ReviewSummary> reviewSummaryAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.textPrimary,
            AppColors.textPrimary.withValues(alpha: 0.88),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: reviewSummaryAsync.when(
        data: (summary) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '嗨，今天先做最有幫助的三件事',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '目前有 ${summary.dueCount} 題待複習，今天已回顧 ${summary.reviewedTodayCount} 題。',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
        loading: () => const SizedBox(
          height: 72,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        error: (_, __) => const Text(
          '先從拍題開始也可以。',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }

  Widget _buildReviewCard(
    BuildContext context,
    AsyncValue<ReviewSummary> reviewSummaryAsync,
  ) {
    return reviewSummaryAsync.when(
      data: (summary) => _buildActionCard(
        title: '錯題複習',
        subtitle: summary.dueCount == 0 ? '今天沒有到期複習，去看看錯題本也行' : '把昨天的錯，變成今天的會',
        trailingText: summary.dueCount == 0 ? '查看' : '${summary.dueCount} 題待複習',
        color: const Color(0xFF7B61FF),
        icon: Icons.refresh_rounded,
        onTap: () {
          AppUX.feedbackClick();
          Navigator.of(context).push(
            AppUX.fadeRoute(const ReviewPage()),
          );
        },
      ),
      loading: () => _buildActionCard(
        title: '錯題複習',
        subtitle: '正在準備今天該複習的題目',
        trailingText: '整理中',
        color: const Color(0xFF7B61FF),
        icon: Icons.refresh_rounded,
        onTap: null,
      ),
      error: (_, __) => _buildActionCard(
        title: '錯題複習',
        subtitle: '先去錯題本看看最近收藏的題目',
        trailingText: '查看',
        color: const Color(0xFF7B61FF),
        icon: Icons.refresh_rounded,
        onTap: onOpenMistakesTab,
      ),
    );
  }

  Widget _buildTasksCard(AsyncValue<DailyTasksData> tasksAsync) {
    return tasksAsync.when(
      data: (tasksData) => _buildActionCard(
        title: '今日任務',
        subtitle: '不用想先做什麼，照著做就進步',
        trailingText:
            '${tasksData.completedCount}/${tasksData.tasks.length} 完成',
        color: const Color(0xFF00A86B),
        icon: Icons.checklist_rounded,
        progress: tasksData.completionRate,
        onTap: () {
          AppUX.feedbackClick();
          onOpenTasksTab();
        },
      ),
      loading: () => _buildActionCard(
        title: '今日任務',
        subtitle: '正在整理今天最值得做的任務',
        trailingText: '準備中',
        color: const Color(0xFF00A86B),
        icon: Icons.checklist_rounded,
        onTap: null,
      ),
      error: (_, __) => _buildActionCard(
        title: '今日任務',
        subtitle: '先去拍一題或複習一題，也算今天有進步',
        trailingText: '查看',
        color: const Color(0xFF00A86B),
        icon: Icons.checklist_rounded,
        onTap: onOpenTasksTab,
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required String trailingText,
    required Color color,
    required IconData icon,
    required VoidCallback? onTap,
    double? progress,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              trailingText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentMistakeCard(Mistake mistake) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            if (mistake.imagePath.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _smallTag(mistake.subject, const Color(0xFFFF9800)),
                      _smallTag(mistake.category, const Color(0xFF2196F3)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    LatexHelper.toReadableText(
                      mistake.title,
                      fallback: '未命名題目',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
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

  Widget _buildEmptyRecentCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        '還沒有錯題，先拍一題開始建立你的專屬錯題本。',
        style: TextStyle(
          color: AppColors.textSecondary,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _smallTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
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
