import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_ux.dart';
import '../../../core/widgets/premium_card.dart';
import '../providers/exam_countdown_provider.dart';

class ExamCountdownPage extends ConsumerStatefulWidget {
  const ExamCountdownPage({super.key});

  @override
  ConsumerState<ExamCountdownPage> createState() => _ExamCountdownPageState();
}

class _ExamCountdownPageState extends ConsumerState<ExamCountdownPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(examCountdownControllerProvider).seedIfEmpty();
    });
  }

  @override
  Widget build(BuildContext context) {
    final examsAsync = ref.watch(examCountdownProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExamEditor(context),
        backgroundColor: AppColors.textPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('新增考試'),
      ),
      body: examsAsync.when(
        data: (data) => CustomScrollView(
          slivers: [
            const SliverAppBar(
              floating: true,
              backgroundColor: Color(0xFFFAFAFA),
              elevation: 0,
              title: Text('考試倒數'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: _NextExamHero(nextExam: data.nextExam),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _WidgetHintCard(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: data.exams.isEmpty
                  ? const SliverToBoxAdapter(child: _EmptyExams())
                  : SliverList.builder(
                      itemCount: data.exams.length,
                      itemBuilder: (context, index) {
                        final exam = data.exams[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ExamCard(
                            exam: exam,
                            onEdit: () => _showExamEditor(context, exam: exam),
                            onDelete: () => _deleteExam(exam),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('載入失敗：$e')),
      ),
    );
  }

  Future<void> _deleteExam(ExamCountdown exam) async {
    await ref.read(examCountdownControllerProvider).deleteExam(exam.id);
    if (!mounted) return;
    AppUX.showSnackBar(context, '已刪除 ${exam.name}');
  }

  Future<void> _showExamEditor(BuildContext context,
      {ExamCountdown? exam}) async {
    final nameController = TextEditingController(text: exam?.name ?? '');
    var selectedDate =
        exam?.examDate ?? DateTime.now().add(const Duration(days: 7));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 拖曳把手
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 標題
                    Text(
                      exam == null ? '新增考試' : '編輯考試',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 考試名稱欄位
                    TextField(
                      controller: nameController,
                      autofocus: exam == null,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: '考試名稱',
                        hintText: '例如：段考、學測、英文模擬考',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // 快速填入捷徑
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kExamPresets.map((preset) {
                        final isCurrent = nameController.text.trim() == preset;
                        return GestureDetector(
                          onTap: () {
                            nameController.text = preset;
                            setSheetState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? AppColors.textPrimary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: isCurrent
                                    ? AppColors.textPrimary
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              preset,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isCurrent
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // 考試日期
                    const Text(
                      '考試日期',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_rounded,
                                color: Color(0xFF6366F1)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('yyyy 年 MM 月 dd 日')
                                        .format(selectedDate),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _previewCountdown(selectedDate),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.textTertiary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 確認按鈕
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final pageCtx = this.context;
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            AppUX.showSnackBar(ctx, '請先輸入考試名稱', isError: true);
                            return;
                          }
                          await ref
                              .read(examCountdownControllerProvider)
                              .saveExam(ExamCountdown(
                                id: exam?.id ??
                                    'exam_${DateTime.now().millisecondsSinceEpoch}',
                                name: name,
                                examDate: selectedDate,
                              ));
                          if (!mounted || !sheetContext.mounted) return;
                          Navigator.of(sheetContext).pop();
                          AppUX.showSnackBar(
                              pageCtx, exam == null ? '已新增考試' : '已更新考試');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.textPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          exam == null ? '建立倒數' : '儲存變更',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _previewCountdown(DateTime date) {
    final diff = DateTime(date.year, date.month, date.day)
        .difference(DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day))
        .inDays;
    if (diff > 0) return '距今 $diff 天（D-$diff）';
    if (diff == 0) return '就是今天';
    return '已過 ${diff.abs()} 天';
  }
}

// ===========================================================================
// Hero card
// ===========================================================================

class _NextExamHero extends StatelessWidget {
  const _NextExamHero({required this.nextExam});
  final ExamCountdown? nextExam;

  @override
  Widget build(BuildContext context) {
    final exam = nextExam;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: exam == null
          ? const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('還沒設定考試',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                  '加上段考、學測或會考日期，\n首頁和桌面 Widget 就會自動開始倒數。',
                  style: TextStyle(color: Colors.white70, height: 1.6),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exam.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          )),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('yyyy/MM/dd').format(exam.examDate),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    examCountdownLabel(exam),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ===========================================================================
// Exam card
// ===========================================================================

class _ExamCard extends StatelessWidget {
  const _ExamCard({
    required this.exam,
    required this.onEdit,
    required this.onDelete,
  });

  final ExamCountdown exam;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isPast =
        DateTime(exam.examDate.year, exam.examDate.month, exam.examDate.day)
            .isBefore(DateTime(
                DateTime.now().year, DateTime.now().month, DateTime.now().day));
    final accent = isPast ? AppColors.textTertiary : const Color(0xFF6366F1);

    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // 左側 D-day 圓形
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                examCountdownLabel(exam),
                style: TextStyle(
                  fontSize: isPast ? 10 : 13,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // 名稱 + 日期
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exam.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isPast
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    )),
                const SizedBox(height: 4),
                Text(
                  DateFormat('yyyy/MM/dd').format(exam.examDate),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          // 編輯 / 刪除
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textTertiary),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('編輯'),
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppColors.error),
                  SizedBox(width: 10),
                  Text('刪除', style: TextStyle(color: AppColors.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Widget hint card
// ===========================================================================

class _WidgetHintCard extends StatelessWidget {
  const _WidgetHintCard();

  @override
  Widget build(BuildContext context) {
    return const PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.widgets_outlined, color: Color(0xFF6366F1)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('桌面 Widget',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                SizedBox(height: 6),
                Text(
                  '設定好考試後，桌面 Widget 會顯示最近一場倒數；點一下可直接進入複習。',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Empty state
// ===========================================================================

class _EmptyExams extends StatelessWidget {
  const _EmptyExams();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: PremiumCard(
        child: Column(
          children: [
            Icon(Icons.event_note_outlined,
                size: 56, color: AppColors.textTertiary),
            SizedBox(height: 12),
            Text('還沒有設定任何考試',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            SizedBox(height: 8),
            Text(
              '點右下角的「新增考試」，\n輸入名稱和日期就完成了。',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
