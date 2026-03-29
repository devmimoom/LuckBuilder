import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/models/mistake.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/home_mesh_reference_colors.dart';
import '../../../core/widgets/feature_setup_chrome.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/utils/app_ux.dart';
import '../../../core/utils/latex_helper.dart';
import '../../mistakes/providers/mistakes_provider.dart';
import '../providers/review_provider.dart';

class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({
    super.key,
    this.initialMode,
  });

  final ReviewMode? initialMode;

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  bool _didAutoStart = false;
  final Map<int, String> _recoveredTitles = <int, String>{};
  final Set<int> _recoveringIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final queuesAsync = ref.watch(reviewQueuesProvider);
    final summaryAsync = ref.watch(reviewSummaryProvider);
    final session = ref.watch(reviewSessionProvider);
    final sessionController = ref.read(reviewSessionProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(session.hasStarted ? '錯題複習中' : '錯題複習'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: queuesAsync.when(
        data: (queues) {
          _autoStartIfNeeded(queues, sessionController, session.hasStarted);

          if (session.hasStarted) {
            if (session.isFinished) {
              return _buildCompletedView(context, session, sessionController);
            }
            final currentMistake = session.currentMistake!;
            return _buildSessionView(context, currentMistake, session);
          }

          return _buildEntryView(
              context, queues, summaryAsync, sessionController);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('載入複習資料失敗：$error')),
      ),
    );
  }

  void _autoStartIfNeeded(
    ReviewQueues queues,
    ReviewSessionController controller,
    bool hasStarted,
  ) {
    if (_didAutoStart || hasStarted || widget.initialMode == null) return;
    _didAutoStart = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final queue = _queueForMode(queues, widget.initialMode!);
      if (queue.isNotEmpty) {
        controller.start(queue);
      }
    });
  }

  List<Mistake> _queueForMode(ReviewQueues queues, ReviewMode mode) {
    switch (mode) {
      case ReviewMode.quick:
        return queues.quick;
      case ReviewMode.standard:
        return queues.standard;
      case ReviewMode.weakSpot:
        return queues.weakSpot;
    }
  }

  Widget _buildEntryView(
    BuildContext context,
    ReviewQueues queues,
    AsyncValue<ReviewSummary> summaryAsync,
    ReviewSessionController controller,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHeaderCard(summaryAsync),
        const SizedBox(height: 20),
        _buildModeCard(
          title: '快速複習',
          subtitle: queues.quick.isEmpty ? '目前沒有待複習題目' : '5 題 / 約 5 分鐘',
          badge: '${queues.quick.length} 題',
          onTap: queues.quick.isEmpty
              ? null
              : () => controller.start(queues.quick),
        ),
        const SizedBox(height: 12),
        _buildModeCard(
          title: '一般複習',
          subtitle: queues.standard.isEmpty ? '目前沒有待複習題目' : '10 題 / 約 10-15 分鐘',
          badge: '${queues.standard.length} 題',
          onTap: queues.standard.isEmpty
              ? null
              : () => controller.start(queues.standard),
        ),
        const SizedBox(height: 12),
        _buildModeCard(
          title: '弱點專攻',
          subtitle: queues.weakSpot.isEmpty
              ? '先累積更多錯題資料'
              : '優先補強 ${queues.weakSpotLabel}',
          badge: '${queues.weakSpot.length} 題',
          onTap: queues.weakSpot.isEmpty
              ? null
              : () => controller.start(queues.weakSpot),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(AsyncValue<ReviewSummary> summaryAsync) {
    return summaryAsync.when(
      data: (summary) => FeatureSetupHero(
        paletteIndex: HomeFeatureCardPaletteIndex.review,
        title: '每一次複習，都在鞏固你的實力',
        subtitle:
            '待複習 ${summary.dueCount} 題，今天已完成 ${summary.reviewedTodayCount} 題',
      ),
      loading: () => const SizedBox(
        height: 72,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          '暫時無法取得複習摘要',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required String badge,
    required VoidCallback? onTap,
  }) {
    return PremiumCard(
      backgroundOpacity: 0.52,
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
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
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.highlight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: AppColors.highlight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionView(
    BuildContext context,
    Mistake mistake,
    ReviewSessionState session,
  ) {
    final controller = ref.read(reviewSessionProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '第 ${session.currentIndex + 1} / ${session.queue.length} 題',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildProblemCard(mistake),
        const SizedBox(height: 16),
        if (!session.showAnswer)
          FilledButton(
            onPressed: () {
              AppUX.feedbackClick();
              controller.revealAnswer();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('看解答'),
          ),
        if (session.showAnswer) ...[
          _buildSolutionCard(mistake),
          const SizedBox(height: 16),
          const Text(
            '你現在覺得這題掌握得怎麼樣？',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildOutcomeButton(
            label: '會了',
            subtitle: '太好了！下次隔久一點再複習',
            color: const Color(0xFF2E7D32),
            onTap: () => controller.submitOutcome(ReviewOutcome.mastered),
          ),
          const SizedBox(height: 10),
          _buildOutcomeButton(
            label: '半懂',
            subtitle: '快到了，近期再練一次就能掌握',
            color: const Color(0xFFF9A825),
            onTap: () => controller.submitOutcome(ReviewOutcome.almost),
          ),
          const SizedBox(height: 10),
          _buildOutcomeButton(
            label: '不會',
            subtitle: '沒關係，明天再來一次就好',
            color: AppColors.error,
            onTap: () => controller.submitOutcome(ReviewOutcome.retry),
          ),
        ],
      ],
    );
  }

  Widget _buildProblemCard(Mistake mistake) {
    _recoverTitleIfNeeded(mistake);
    final file = mistake.imagePath.isNotEmpty ? File(mistake.imagePath) : null;
    final displayTitle = _resolvedTitle(mistake);

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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetaChip(mistake.subject, const Color(0xFFFF9800)),
              _buildMetaChip(mistake.category, const Color(0xFF2196F3)),
            ],
          ),
          if (file != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: AppColors.surface,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          LatexText(
            text: displayTitle,
            fontSize: 15,
            lineHeight: 1.7,
          ),
          if (_isRecovering(mistake)) ...[
            const SizedBox(height: 8),
            const Text(
              '正在還原完整題目...',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _resolvedTitle(Mistake mistake) {
    final id = mistake.id;
    if (id == null) return mistake.title;
    return _recoveredTitles[id] ?? mistake.title;
  }

  bool _isRecovering(Mistake mistake) {
    final id = mistake.id;
    if (id == null) return false;
    return _recoveringIds.contains(id);
  }

  bool _looksTruncated(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.endsWith('...')) return true;
    if (trimmed.contains(r'\overline...')) return true;
    return false;
  }

  void _recoverTitleIfNeeded(Mistake mistake) {
    final id = mistake.id;
    if (id == null) return;
    if (!_looksTruncated(mistake.title)) return;
    if (_recoveringIds.contains(id) || _recoveredTitles.containsKey(id)) return;
    if (mistake.imagePath.isEmpty) return;

    _recoveringIds.add(id);
    unawaited(_recoverTitleFromImage(mistake));
  }

  Future<void> _recoverTitleFromImage(Mistake mistake) async {
    final id = mistake.id;
    if (id == null) return;

    try {
      final imageFile = File(mistake.imagePath);
      if (!await imageFile.exists()) return;

      final recognized = await GeminiService().recognizeImage(imageFile);
      final recovered = (recognized ?? '').trim();
      if (recovered.isEmpty || recovered == mistake.title) return;

      if (!mounted) return;
      setState(() {
        _recoveredTitles[id] = recovered;
      });

      // 回寫資料庫，避免下次還要重跑 OCR。
      await ref.read(mistakesProvider.notifier).updateMistakeTitle(
            id: id,
            title: recovered,
          );
    } catch (_) {
      // OCR 還原失敗時保持原顯示，不阻塞複習流程。
    } finally {
      if (mounted) {
        setState(() {
          _recoveringIds.remove(id);
        });
      } else {
        _recoveringIds.remove(id);
      }
    }
  }

  Widget _buildSolutionCard(Mistake mistake) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '解題重點',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...mistake.solutions.map(
            (solution) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LatexText(
                text: solution,
                fontSize: 14,
                lineHeight: 1.75,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeButton({
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedView(
    BuildContext context,
    ReviewSessionState session,
    ReviewSessionController controller,
  ) {
    final mastered = session.outcomes.values
        .where((outcome) => outcome == ReviewOutcome.mastered)
        .length;
    final almost = session.outcomes.values
        .where((outcome) => outcome == ReviewOutcome.almost)
        .length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '做得好！今天的複習完成了',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '這次完成 ${session.completedCount} 題，其中 $mastered 題已經穩了，$almost 題還要再熟一點。持續複習是最有效的學習方式，明天見！',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                controller.reset();
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('返回'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
