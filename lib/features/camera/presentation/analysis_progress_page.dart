import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/utils/app_ux.dart';
import '../../solver/presentation/solver_page.dart';
import '../providers/analysis_provider.dart';

class AnalysisProgressPage extends ConsumerWidget {
  const AnalysisProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(analysisQueueProvider);
    final allCompleted = tasks.isNotEmpty && 
        tasks.every((t) => t.status == AnalysisStatus.completed);

    return Scaffold(
      appBar: AppBar(
        title: const Text("AI 智能解析中"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              // 如果無法 pop，則返回到第一個路由（主頁）
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
        ),
      ),
      body: Column(
        children: [
          // 1. 頂部狀態摘要
          _buildHeader(tasks),

          // 2. 任務列表
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _buildTaskCard(context, ref, task);
              },
            ),
          ),

          // 3. 底部按鈕
          _buildFooter(context, ref, allCompleted),
        ],
      ),
    );
  }

  Widget _buildHeader(List<AnalysisTask> tasks) {
    final completedCount = tasks.where((t) => t.status == AnalysisStatus.completed).length;
    final total = tasks.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      width: double.infinity,
      color: AppColors.surface,
      child: Column(
        children: [
          Text(
            completedCount == total ? "解析完成！" : "正在解析第 ${completedCount + 1} 題",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : completedCount / total,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.highlight),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "請稍候，AI 正在為你生成避坑指南 ($completedCount/$total)",
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, WidgetRef ref, AnalysisTask task) {
    final isFailed = task.status == AnalysisStatus.failed;
    
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      onTap: task.status == AnalysisStatus.completed
          ? () {
              AppUX.feedbackClick();
              // 確保有裁切圖片或原始圖片
              // 傳遞完整的解析結果到 SolverPage（包含 OCR 結果和 Gemini 解析結果）
              final imagePath = task.cropPath ?? task.imagePath;
              final imageFile = imagePath != null ? File(imagePath) : null;
              
              Navigator.of(context).push(
                AppUX.fadeRoute(
                  SolverPage(
                    originalImage: imageFile,
                    initialLatex: task.resultLatex, // OCR 辨識的題目文字
                    gradeLevel: task.gradeLevel, // 年級
                    chapter: task.chapter, // 章節（或「待建立」）
                    keyConcepts: task.keyConcepts, // 核心觀念
                    solutions: task.solutions, // 解法列表
                  ),
                ),
              ).then((_) {
                // SolverPage 返回時，自動回到「解題分析」tab
                // SolverPage 內部會處理 pop 邏輯
              });
            }
          : isFailed
              ? () {
                  // 失敗時可以重試
                  AppUX.feedbackClick();
                  _showRetryDialog(context, ref, task);
                }
              : null,
      child: Row(
        children: [
          // 縮圖預覽 (模擬)
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.crop_original, color: AppColors.textTertiary),
          ),
          const SizedBox(width: 16),
          // 標題與狀態
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title ?? (task.status == AnalysisStatus.completed 
                      ? "${task.chapter ?? '待建立'} • ${task.gradeLevel ?? ''}"
                      : "等待解析中..."),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: task.status == AnalysisStatus.waiting 
                        ? AppColors.textTertiary 
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                if (task.status == AnalysisStatus.processing)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: task.progress,
                      minHeight: 2,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.highlight),
                    ),
                  )
                else if (task.status == AnalysisStatus.failed)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusText(task.status),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(task.status),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "點擊重試",
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    _getStatusText(task.status),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getStatusColor(task.status),
                    ),
                  ),
              ],
            ),
          ),
          // 右側圖示
          _buildStatusIcon(task.status),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(AnalysisStatus status) {
    switch (status) {
      case AnalysisStatus.waiting:
        return const Icon(Icons.hourglass_empty, size: 20, color: AppColors.textTertiary);
      case AnalysisStatus.processing:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.highlight),
        );
      case AnalysisStatus.completed:
        return const Icon(Icons.check_circle, size: 20, color: Colors.green);
      case AnalysisStatus.failed:
        return const Icon(Icons.error, size: 20, color: AppColors.error);
    }
  }

  String _getStatusText(AnalysisStatus status) {
    switch (status) {
      case AnalysisStatus.waiting: return "排隊中";
      case AnalysisStatus.processing: return "正在計算...";
      case AnalysisStatus.completed: 
        return "解析完成（題目+答案+分類），點擊查看詳解";
      case AnalysisStatus.failed: return "辨識失敗";
    }
  }

  Color _getStatusColor(AnalysisStatus status) {
    switch (status) {
      case AnalysisStatus.waiting: return AppColors.textTertiary;
      case AnalysisStatus.processing: return AppColors.highlight;
      case AnalysisStatus.completed: return Colors.green;
      case AnalysisStatus.failed: return AppColors.error;
    }
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref, bool allCompleted) {
    final tasks = ref.watch(analysisQueueProvider);
    final completedTasks = tasks.where((t) => t.status == AnalysisStatus.completed).toList();
    final hasCompleted = completedTasks.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 如果有完成的題目（>=1），就顯示「查看已完成的解析」按鈕（不需要等待所有任務完成）
            if (hasCompleted) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    AppUX.feedbackClick();
                    // 收集所有完成的任務數據
                    final problems = completedTasks.map((task) {
                      final imagePath = task.cropPath ?? task.imagePath;
                      final imageFile = imagePath != null ? File(imagePath) : null;
                      
                      return {
                        'image': imageFile,
                        'latex': task.resultLatex,
                        'subject': task.subject ?? '其他',
                        'category': task.category ?? '其他',
                        'gradeLevel': task.gradeLevel,
                        'chapter': task.chapter,
                        'keyConcepts': task.keyConcepts,
                        'solutions': task.solutions,
                      };
                    }).toList();
                    
                    // 導航到 SolverPage，傳遞所有題目數據
                    Navigator.of(context).push(
                      AppUX.fadeRoute(
                        SolverPage(
                          multipleProblems: problems,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.view_carousel, color: Colors.white),
                  label: Text("查看已完成的解析 (${completedTasks.length} 題)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // 回到主頁按鈕
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: allCompleted ? () => Navigator.of(context).popUntil((route) => route.isFirst) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: allCompleted ? AppColors.textSecondary : AppColors.border,
                  disabledBackgroundColor: AppColors.border,
                ),
                child: Text(allCompleted ? "回到主頁" : "AI 正在努力中..."),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRetryDialog(BuildContext context, WidgetRef ref, AnalysisTask task) {
    // 找到任務的索引
    final tasks = ref.read(analysisQueueProvider);
    final taskIndex = tasks.indexWhere((t) => t.id == task.id);
    
    if (taskIndex == -1) {
      AppUX.showSnackBar(context, "找不到任務", isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("辨識失敗"),
        content: Text(
          task.title ?? "無法辨識此題目，可能是圖片模糊或 API 錯誤。",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              AppUX.feedbackClick();
              // 執行重試
              ref.read(analysisQueueProvider.notifier).retryTask(taskIndex);
            },
            child: const Text("重試"),
          ),
        ],
      ),
    );
  }
}
