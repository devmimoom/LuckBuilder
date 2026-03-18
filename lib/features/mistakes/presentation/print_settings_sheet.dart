import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../providers/print_provider.dart';
import '../providers/mistakes_provider.dart';
import '../../../core/database/models/mistake.dart';
import '../../../core/utils/app_ux.dart';
import 'print_pdf_generator.dart';
import 'pdf_preview_page.dart';

/// 列印設定 Bottom Sheet
class PrintSettingsSheet extends ConsumerWidget {
  const PrintSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(printSettingsNotifierProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // 頂部拖曳指示器
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 標題
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '列印設定',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        AppUX.feedbackClick();
                        ref
                            .read(printSettingsNotifierProvider.notifier)
                            .reset();
                      },
                      child: const Text('重置'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // 設定選項
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // 內容選項
                    _buildSectionTitle('列印內容'),
                    const SizedBox(height: 8),
                    ...PrintContentOption.values.map((option) {
                      return _ContentOptionTile(
                        option: option,
                        isSelected: settings.contentOption == option,
                        onTap: () {
                          AppUX.feedbackClick();
                          ref
                              .read(printSettingsNotifierProvider.notifier)
                              .setContentOption(option);
                        },
                      );
                    }),

                    const SizedBox(height: 24),

                    // 每頁題數
                    _buildSectionTitle('每頁題數'),
                    const SizedBox(height: 8),
                    Row(
                      children: QuestionsPerPage.values.map((option) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _QuestionsPerPageChip(
                              option: option,
                              isSelected: settings.questionsPerPage == option,
                              onTap: () {
                                AppUX.feedbackClick();
                                ref
                                    .read(
                                        printSettingsNotifierProvider.notifier)
                                    .setQuestionsPerPage(option);
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // 排序方式
                    _buildSectionTitle('排序方式'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: SortOption.values.map((option) {
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(option.icon, size: 16),
                              const SizedBox(width: 4),
                              Text(option.title),
                            ],
                          ),
                          selected: settings.sortOption == option,
                          onSelected: (_) {
                            AppUX.feedbackClick();
                            ref
                                .read(printSettingsNotifierProvider.notifier)
                                .setSortOption(option);
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // 其他選項
                    _buildSectionTitle('其他選項'),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('包含題目圖片'),
                      subtitle: const Text('列印原始題目圖片'),
                      value: settings.includeImages,
                      onChanged: (value) {
                        AppUX.feedbackClick();
                        ref
                            .read(printSettingsNotifierProvider.notifier)
                            .setIncludeImages(value);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('顯示日期'),
                      subtitle: const Text('在每題旁邊顯示建立日期'),
                      value: settings.showDate,
                      onChanged: (value) {
                        AppUX.feedbackClick();
                        ref
                            .read(printSettingsNotifierProvider.notifier)
                            .setShowDate(value);
                      },
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
              // 底部按鈕
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _previewPdf(context, ref),
                          icon: const Icon(Icons.visibility),
                          label: const Text('預覽'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _generateAndShare(context, ref),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('產生 PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Future<void> _previewPdf(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(printSettingsNotifierProvider);
    final selectedIds = ref.read(selectionNotifierProvider).selectedIds;
    final mistakesAsync = ref.read(mistakesProvider);

    final mistakes = mistakesAsync.maybeWhen(
      data: (allMistakes) {
        return allMistakes
            .where((m) => m.id != null && selectedIds.contains(m.id))
            .toList();
      },
      orElse: () => <Mistake>[],
    );

    if (mistakes.isEmpty) {
      if (context.mounted) {
        AppUX.showSnackBar(context, '請至少選擇一題', isError: true);
      }
      return;
    }

    try {
      final pdfBytes = await PrintPdfGenerator.generate(mistakes, settings);

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewPage(pdfBytes: pdfBytes),
          ),
        );
      }
    } catch (e) {
      debugPrint('預覽 PDF 失敗: $e');
      if (context.mounted) {
        AppUX.showSnackBar(context, '預覽失敗，請重試', isError: true);
      }
    }
  }

  Future<void> _generateAndShare(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(printSettingsNotifierProvider);
    final selectedIds = ref.read(selectionNotifierProvider).selectedIds;
    final mistakesAsync = ref.read(mistakesProvider);

    final mistakes = mistakesAsync.maybeWhen(
      data: (allMistakes) {
        return allMistakes
            .where((m) => m.id != null && selectedIds.contains(m.id))
            .toList();
      },
      orElse: () => <Mistake>[],
    );

    if (mistakes.isEmpty) {
      if (context.mounted) {
        AppUX.showSnackBar(context, '請至少選擇一題', isError: true);
      }
      return;
    }

    try {
      final pdfBytes = await PrintPdfGenerator.generate(mistakes, settings);

      if (!context.mounted) return;
      final navigator = Navigator.of(context);

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: '錯題本_${DateTime.now().toString().substring(0, 10)}.pdf',
      );
      navigator.pop(); // 關閉設定頁面
      ref
          .read(selectionNotifierProvider.notifier)
          .exitSelectionMode(); // 退出選取模式
    } catch (e) {
      debugPrint('產生 PDF 失敗: $e');
      if (context.mounted) {
        AppUX.showSnackBar(context, '產生 PDF 失敗，請重試', isError: true);
      }
    }
  }
}

/// 內容選項卡片
class _ContentOptionTile extends StatelessWidget {
  final PrintContentOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _ContentOptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF2196F3) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? const Color(0xFF2196F3).withValues(alpha: 0.05)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF2196F3) : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          isSelected ? const Color(0xFF2196F3) : Colors.black87,
                    ),
                  ),
                  Text(
                    option.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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

/// 每頁題數選項
class _QuestionsPerPageChip extends StatelessWidget {
  final QuestionsPerPage option;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuestionsPerPageChip({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF2196F3) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? const Color(0xFF2196F3).withValues(alpha: 0.05)
              : null,
        ),
        child: Column(
          children: [
            Text(
              option.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF2196F3) : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              option.subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
