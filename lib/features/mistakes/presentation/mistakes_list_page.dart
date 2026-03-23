import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_image_viewer.dart';
import '../../../core/services/mistake_share_service.dart';
import '../../../core/utils/app_ux.dart';
import '../../../core/utils/latex_helper.dart';
import '../providers/mistakes_provider.dart';
import '../providers/print_provider.dart';
import '../../../core/database/models/mistake.dart';
import '../../solver/presentation/solver_page.dart';
import 'print_settings_sheet.dart';
import 'glyph_test_page.dart';
import '../../settings/presentation/settings_page.dart';
import 'dart:io';

class MistakesListPage extends ConsumerStatefulWidget {
  const MistakesListPage({super.key});

  @override
  ConsumerState<MistakesListPage> createState() => _MistakesListPageState();
}

class _MistakesListPageState extends ConsumerState<MistakesListPage> {
  bool _isNavigatingToSolver = false;

  Future<void> _openSolverPage({
    required BuildContext context,
    required Mistake mistake,
  }) async {
    if (_isNavigatingToSolver || !mounted) return;
    _isNavigatingToSolver = true;

    try {
      final imagePath = mistake.imagePath;
      File? imageFile;
      if (imagePath.isNotEmpty) {
        // 只建立 File 參考，不在 UI 執行緒做同步 exists 檢查
        imageFile = File(imagePath);
      }

      await Navigator.of(context).push(
        AppUX.fadeRoute(
          SolverPage(
            originalImage: imageFile,
            initialLatex: mistake.title,
            isFromMistakes: true,
            savedSolutions: mistake.solutions,
            subject: mistake.subject,
            category: mistake.category,
            chapter: mistake.resolvedChapter,
            keyConcepts: mistake.resolvedKeyConcepts,
            mistakeId: mistake.id,
          ),
        ),
      );
    } finally {
      _isNavigatingToSolver = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mistakesAsync = ref.watch(mistakesProvider);
    final filter = ref.watch(mistakeFiltersProvider);
    final selection = ref.watch(selectionNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // 1. AppBar
          SliverAppBar(
            floating: true,
            title: Text(_getAppBarTitle(ref)),
            leading: _buildAppBarLeading(ref),
            actions: _buildAppBarActions(context, ref),
          ),

          // 2. Level 1: 科目切換列 (Sticky Tabs)
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              minHeight: 50.0,
              maxHeight: 50.0,
              child: Container(
                color: AppColors.background,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSubjectTab(ref, "全部", filter['subject'] == "全部"),
                      _buildSubjectTab(ref, "數學", filter['subject'] == "數學"),
                      _buildSubjectTab(ref, "英文", filter['subject'] == "英文"),
                      _buildSubjectTab(ref, "國文", filter['subject'] == "國文"),
                      _buildSubjectTab(ref, "自然", filter['subject'] == "自然"),
                      _buildSubjectTab(ref, "地理", filter['subject'] == "地理"),
                      _buildSubjectTab(ref, "歷史", filter['subject'] == "歷史"),
                      _buildSubjectTab(ref, "公民", filter['subject'] == "公民"),
                      _buildSubjectTab(ref, "其他", filter['subject'] == "其他"),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Level 2: 智慧篩選 (Smart Chips)
          SliverToBoxAdapter(
            child: _buildFilterChips(ref),
          ),

          // 4. Content: 錯題列表
          mistakesAsync.when(
            data: (mistakes) {
              if (mistakes.isEmpty) {
                return SliverFillRemaining(child: _buildEmptyState());
              }
              final groupedMistakes = _groupMistakesByDate(mistakes);
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final date = groupedMistakes.keys.elementAt(index);
                    final dateMistakes = groupedMistakes[date]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateHeader(date),
                        ...dateMistakes.asMap().entries.map((entry) {
                          final mIndex = entry.key;
                          final m = entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Dismissible(
                              key: Key('mistake_${m.id}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE02E2E),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delete_outline,
                                    color: Colors.white, size: 28),
                              ),
                              confirmDismiss: (direction) async {
                                HapticFeedback.mediumImpact();
                                return true;
                              },
                              onDismissed: (direction) {
                                ref
                                    .read(mistakesProvider.notifier)
                                    .deleteMistake(m.id!);
                              },
                              child: _MistakeCardWithSelection(
                                mistake: m,
                                onTap: () {
                                  if (selection.isSelectionMode) {
                                    ref
                                        .read(
                                            selectionNotifierProvider.notifier)
                                        .toggleSelection(m.id!);
                                  } else {
                                    _openSolverPage(
                                        context: context, mistake: m);
                                  }
                                },
                                onLongPress: () {
                                  if (!selection.isSelectionMode) {
                                    ref
                                        .read(
                                            selectionNotifierProvider.notifier)
                                        .enterSelectionMode();
                                    ref
                                        .read(
                                            selectionNotifierProvider.notifier)
                                        .toggleSelection(m.id!);
                                  }
                                },
                                isSelectionMode: selection.isSelectionMode,
                                isSelected: selection.isSelected(m.id!),
                              )
                                  .animate(delay: (mIndex * 50).ms)
                                  .fadeIn(
                                      duration: 400.ms, curve: Curves.easeOut)
                                  .slideY(begin: 0.1, end: 0, duration: 400.ms),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                  childCount: groupedMistakes.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (err, stack) =>
                SliverFillRemaining(child: Center(child: Text('載入失敗: $err'))),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context, ref),
    );
  }

  String _getAppBarTitle(WidgetRef ref) {
    final selection = ref.watch(selectionNotifierProvider);
    if (selection.isSelectionMode) {
      return '已選取 ${selection.selectedCount} 題';
    }
    return '我的錯題本';
  }

  Widget? _buildAppBarLeading(WidgetRef ref) {
    final selection = ref.watch(selectionNotifierProvider);
    if (selection.isSelectionMode) {
      return IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          AppUX.feedbackClick();
          ref.read(selectionNotifierProvider.notifier).exitSelectionMode();
        },
      );
    }
    return null;
  }

  List<Widget> _buildAppBarActions(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectionNotifierProvider);
    if (selection.isSelectionMode) {
      return [
        TextButton(
          onPressed: () {
            AppUX.feedbackClick();
            final mistakesAsync = ref.read(mistakesProvider);
            mistakesAsync.maybeWhen(
              data: (mistakes) {
                final allIds =
                    mistakes.map((m) => m.id!).whereType<int>().toList();
                ref.read(selectionNotifierProvider.notifier).selectAll(allIds);
              },
              orElse: () {},
            );
          },
          child: const Text('全選'),
        ),
        const SizedBox(width: 8),
      ];
    }
    return [
      IconButton(
        icon: const Icon(Icons.text_fields),
        tooltip: '缺字測試',
        onPressed: () {
          AppUX.feedbackClick();
          Navigator.of(context).push(
            AppUX.fadeRoute(const GlyphTestPage()),
          );
        },
      ),
      IconButton(
        icon: const Icon(Icons.search),
        onPressed: () {
          AppUX.feedbackClick();
          _showSearchDialog(context, ref);
        },
      ),
      IconButton(
        icon: const Icon(Icons.print),
        onPressed: () {
          AppUX.feedbackClick();
          ref.read(selectionNotifierProvider.notifier).enterSelectionMode();
        },
      ),
      IconButton(
        icon: const Icon(Icons.settings_outlined),
        tooltip: '設定',
        onPressed: () {
          AppUX.feedbackClick();
          Navigator.of(context).push(
            AppUX.fadeRoute(const SettingsPage()),
          );
        },
      ),
      const SizedBox(width: 8),
    ];
  }

  Widget? _buildBottomBar(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectionNotifierProvider);
    if (!selection.isSelectionMode) return null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  AppUX.feedbackClick();
                  ref
                      .read(selectionNotifierProvider.notifier)
                      .exitSelectionMode();
                },
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: selection.selectedCount > 0
                    ? () {
                        AppUX.feedbackClick();
                        _showPrintSettingsSheet(context, ref);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                ),
                child: Text('列印 (${selection.selectedCount} 題)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrintSettingsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PrintSettingsSheet(),
    );
  }

  Widget _buildSubjectTab(WidgetRef ref, String label, bool isSelected) {
    return GestureDetector(
      onTap: () => ref.read(mistakeFiltersProvider.notifier).setSubject(label),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(WidgetRef ref) {
    final mistakesAsync = ref.watch(mistakesProvider);
    final filter = ref.watch(mistakeFiltersProvider);

    // 獲取當前選中的自訂標籤列表（用於排除）
    final customTags = (filter['customTags'] as List<dynamic>?) ?? [];
    final customTagsSet = customTags.map((t) => t.toString()).toSet();

    // 從所有錯題中提取常用標籤（排除「AI 解析」「AI 練習題」和自訂標籤）
    final popularTags = mistakesAsync.maybeWhen(
      data: (mistakes) {
        final tagCount = <String, int>{};
        for (var mistake in mistakes) {
          for (var tag in mistake.tags) {
            // 排除「AI 解析」「AI 練習題」標籤和自訂標籤
            if (tag != 'AI 解析' &&
                tag != 'AI 練習題' &&
                !customTagsSet.contains(tag)) {
              tagCount[tag] = (tagCount[tag] ?? 0) + 1;
            }
          }
        }
        // 返回出現次數最多的前5個標籤
        final sortedTags = tagCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return sortedTags.take(5).map((e) => e.key).toList();
      },
      orElse: () => <String>[],
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 自訂標籤按鈕（移到最前面）
          Builder(
            builder: (context) => _buildFilterChip(
              ref,
              "✏️ 自訂標籤",
              isAction: true,
              onTap: () {
                AppUX.feedbackClick();
                _showCustomTagDialog(context, ref, mistakesAsync);
              },
            ),
          ),
          // All 選項（清除所有篩選）
          _buildFilterChip(
            ref,
            "All",
            isAction: true,
            isSelected: filter['timeFilter'] == null &&
                filter['errorFilter'] == null &&
                filter['tagFilter'] == null &&
                ((filter['customTags'] as List<dynamic>?) ?? []).isEmpty,
            onTap: () {
              AppUX.feedbackClick();
              ref.read(mistakeFiltersProvider.notifier).clearFilters();
            },
          ),
          // 自訂標籤顯示
          ...((filter['customTags'] as List<dynamic>?) ?? [])
              .map((customTag) => _buildFilterChip(
                    ref,
                    "🏷️ ${customTag.toString()}",
                    isSelected: true,
                    onTap: () {
                      AppUX.feedbackClick();
                      ref
                          .read(mistakeFiltersProvider.notifier)
                          .removeCustomTag(customTag.toString());
                    },
                  )),
          _buildFilterChip(
            ref,
            "📅 近30天",
            isSelected: filter['timeFilter'] == 'first_exam',
            onTap: () {
              AppUX.feedbackClick();
              if (filter['timeFilter'] == 'first_exam') {
                ref.read(mistakeFiltersProvider.notifier).setTimeFilter(null);
              } else {
                ref
                    .read(mistakeFiltersProvider.notifier)
                    .setTimeFilter('first_exam');
              }
            },
          ),
          _buildFilterChip(
            ref,
            "⚠️ 常錯",
            isSelected: filter['errorFilter'] == 'frequent',
            onTap: () {
              AppUX.feedbackClick();
              if (filter['errorFilter'] == 'frequent') {
                ref.read(mistakeFiltersProvider.notifier).setErrorFilter(null);
              } else {
                ref
                    .read(mistakeFiltersProvider.notifier)
                    .setErrorFilter('frequent');
              }
            },
          ),
          _buildFilterChip(
            ref,
            "AI 練習題",
            isSelected: filter['tagFilter'] == 'AI 練習題',
            onTap: () {
              AppUX.feedbackClick();
              if (filter['tagFilter'] == 'AI 練習題') {
                ref.read(mistakeFiltersProvider.notifier).setTagFilter(null);
              } else {
                ref
                    .read(mistakeFiltersProvider.notifier)
                    .setTagFilter('AI 練習題');
              }
            },
          ),
          // 動態標籤（前5個）
          ...popularTags.map((tag) => _buildFilterChip(
                ref,
                "🏷️ $tag",
                isSelected: filter['tagFilter'] == tag,
                onTap: () {
                  AppUX.feedbackClick();
                  if (filter['tagFilter'] == tag) {
                    ref
                        .read(mistakeFiltersProvider.notifier)
                        .setTagFilter(null);
                  } else {
                    ref.read(mistakeFiltersProvider.notifier).setTagFilter(tag);
                  }
                },
              )),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    WidgetRef ref,
    String label, {
    bool isAction = false,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isAction
              ? Colors.transparent
              : isSelected
                  ? AppColors.highlight.withValues(alpha: 0.2)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.highlight : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isAction
                ? AppColors.highlight
                : isSelected
                    ? AppColors.highlight
                    : AppColors.textSecondary,
            fontWeight:
                isAction || isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showCustomTagDialog(BuildContext context, WidgetRef ref,
      AsyncValue<List<Mistake>> mistakesAsync) {
    final TextEditingController controller = TextEditingController();

    final List<String> allTags = mistakesAsync.maybeWhen(
      data: (mistakes) {
        final tagSet = <String>{};
        for (var mistake in mistakes) {
          for (var tag in mistake.tags) {
            if (tag != 'AI 解析' && tag != 'AI 練習題') {
              tagSet.add(tag);
            }
          }
        }
        return tagSet.toList()..sort();
      },
      orElse: () => <String>[],
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, child) {
            final filter = ref.watch(mistakeFiltersProvider);
            final customTags = (filter['customTags'] as List<dynamic>?) ?? [];

            return StatefulBuilder(
              builder: (context, setState) {
                String searchQuery = controller.text;
                final filteredTags = allTags.where((tag) {
                  if (searchQuery.isEmpty) return false;
                  return tag.toLowerCase().contains(searchQuery.toLowerCase());
                }).toList();

                return AlertDialog(
                  title: const Text("輸入自訂標籤"),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 顯示所有已自訂的標籤
                        if (customTags.isNotEmpty) ...[
                          const Text(
                            "已自訂的標籤：",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: customTags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.highlight
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: AppColors.highlight),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tag.toString(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.highlight,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () {
                                        AppUX.feedbackClick();
                                        ref
                                            .read(
                                                mistakeFiltersProvider.notifier)
                                            .removeCustomTag(tag.toString());
                                        // UI 會通過 Consumer 自動更新
                                      },
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: AppColors.highlight,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                        // 輸入框
                        TextField(
                          controller: controller,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: "輸入標籤名稱...",
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            // 觸發 rebuild 以更新建議標籤和「新增」按鈕的顯示狀態
                            setState(() {});
                          },
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              ref
                                  .read(mistakeFiltersProvider.notifier)
                                  .addCustomTag(value.trim());
                              controller.clear();
                              setState(() {}); // 觸發 rebuild 以更新 UI
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        // 建議標籤
                        if (searchQuery.isNotEmpty &&
                            filteredTags.isNotEmpty) ...[
                          const Text(
                            "建議標籤：",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 150),
                            child: SingleChildScrollView(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: filteredTags.map((tag) {
                                  return GestureDetector(
                                    onTap: () {
                                      AppUX.feedbackClick();
                                      ref
                                          .read(mistakeFiltersProvider.notifier)
                                          .addCustomTag(tag);
                                      controller.clear();
                                      setState(() {}); // 觸發 rebuild 以更新 UI
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(8),
                                        border:
                                            Border.all(color: AppColors.border),
                                      ),
                                      child: Text(
                                        tag,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ] else if (searchQuery.isNotEmpty &&
                            filteredTags.isEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              "未找到匹配的標籤",
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("關閉"),
                    ),
                    if (searchQuery.trim().isNotEmpty)
                      TextButton(
                        onPressed: () {
                          AppUX.feedbackClick();
                          final tagToAdd = controller.text.trim();
                          if (tagToAdd.isNotEmpty) {
                            ref
                                .read(mistakeFiltersProvider.notifier)
                                .addCustomTag(tagToAdd);
                            controller.clear();
                            setState(() {}); // 觸發 rebuild 以更新 UI
                          }
                        },
                        child: const Text("新增"),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        date,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Map<String, List<Mistake>> _groupMistakesByDate(List<Mistake> mistakes) {
    final Map<String, List<Mistake>> groups = {};
    final dateFormat = DateFormat('yyyy/MM/dd');
    for (var m in mistakes) {
      final dateStr = dateFormat.format(m.createdAt);
      if (!groups.containsKey(dateStr)) {
        groups[dateStr] = [];
      }
      groups[dateStr]!.add(m);
    }
    return groups;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories_outlined,
              size: 64, color: AppColors.textTertiary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text(
            "題庫空空如也",
            style: TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// 顯示搜尋對話框
  void _showSearchDialog(BuildContext context, WidgetRef ref) {
    final currentQuery = ref.read(mistakeFiltersProvider)['searchQuery'] ?? '';
    final controller = TextEditingController(text: currentQuery.toString());

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('搜尋錯題'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '輸入標題或標籤關鍵字',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            ref.read(mistakeFiltersProvider.notifier).setSearchQuery(value);
            Navigator.of(dialogContext).pop();
          },
        ),
        actions: [
          // 清除按鈕：清空搜尋欄（不關閉對話框，不更新搜尋條件）
          TextButton(
            onPressed: () {
              AppUX.feedbackClick();
              // 只清空輸入欄，不關閉對話框
              controller.clear();
            },
            child: const Text('清除'),
          ),
          // 取消按鈕：關閉對話框，不搜尋
          TextButton(
            onPressed: () {
              AppUX.feedbackClick();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('取消'),
          ),
          // 搜尋按鈕：執行搜尋
          TextButton(
            onPressed: () {
              AppUX.feedbackClick();
              ref
                  .read(mistakeFiltersProvider.notifier)
                  .setSearchQuery(controller.text);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('搜尋'),
          ),
        ],
      ),
    );
  }
}

class MistakeCard extends StatelessWidget {
  final Mistake mistake;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enableImagePreview;

  const MistakeCard({
    super.key,
    required this.mistake,
    this.onTap,
    this.onLongPress,
    this.enableImagePreview = true,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!.call();
          return;
        }

        final imagePath = mistake.imagePath;
        final imageFile = imagePath.isNotEmpty ? File(imagePath) : null;

        Navigator.of(context).push(
          AppUX.fadeRoute(
            SolverPage(
              originalImage: imageFile,
              initialLatex: mistake.title,
              isFromMistakes: true,
              savedSolutions: mistake.solutions,
              subject: mistake.subject,
              category: mistake.category,
              chapter: mistake.resolvedChapter,
              keyConcepts: mistake.resolvedKeyConcepts,
              mistakeId: mistake.id,
            ),
          ),
        );
      },
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildSmallTag(mistake.subject, const Color(0xFFFF9800)),
                    _buildSmallTag(mistake.category, const Color(0xFF2196F3)),
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
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _buildPreviewText(mistake.title),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...mistake.tags
                            .where((t) => t != 'AI 解析')
                            .take(3)
                            .map((t) => _buildLabel(t)),
                        if (mistake.errorReason != null)
                          _buildLabel(
                            mistake.errorReason == 'AI 練習題'
                                ? mistake.errorReason!
                                : '錯誤：${mistake.errorReason}',
                            isHighlight: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  if (!enableImagePreview) {
                    onTap?.call();
                    return;
                  }
                  AppUX.feedbackClick();
                  Navigator.of(context).push(
                    AppUX.fadeRoute(
                      PremiumImageViewer(
                        imagePath: mistake.imagePath,
                        heroTag: 'mistake_image_${mistake.id}',
                      ),
                    ),
                  );
                },
                child: Hero(
                  tag: 'mistake_image_${mistake.id}',
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildThumbnail(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        _buildPreviewText(text),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildLabel(String text, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlight
            ? AppColors.error.withValues(alpha: 0.05)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: isHighlight
                ? AppColors.error.withValues(alpha: 0.2)
                : AppColors.border),
      ),
      child: Text(
        _buildPreviewText(text),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: isHighlight ? AppColors.error : AppColors.textSecondary,
        ),
      ),
    );
  }

  String _buildPreviewText(String text) {
    return LatexHelper.toReadableText(text, fallback: '未命名題目');
  }

  bool get _isAiPracticeMistake {
    return mistake.tags.contains('AI 練習題') || mistake.errorReason == 'AI 練習題';
  }

  Widget _buildThumbnail() {
    if (_isAiPracticeMistake) {
      // 縮圖固定約 70×70，內部可用空間更小；用 FittedBox 避免 Column 溢出
      return const ColoredBox(
        color: Color(0xFFFFF7ED),
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFFF8A00),
                  size: 20,
                ),
                SizedBox(height: 2),
                Text(
                  'AI\n練習題',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _buildImage(mistake.imagePath);
  }

  Widget _buildImage(String path) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported,
          color: AppColors.textTertiary, size: 24),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });
  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

/// 支援選取模式的錯題卡片
class _MistakeCardWithSelection extends StatelessWidget {
  final Mistake mistake;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isSelectionMode;
  final bool isSelected;

  const _MistakeCardWithSelection({
    required this.mistake,
    required this.onTap,
    required this.onLongPress,
    required this.isSelectionMode,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isSelected ? const Color(0xFF2196F3).withValues(alpha: 0.1) : null,
      child: Row(
        children: [
          // 選取模式時顯示勾選框
          if (isSelectionMode) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
          Expanded(
            child: MistakeCard(
              mistake: mistake,
              onTap: onTap,
              onLongPress: onLongPress,
              enableImagePreview: !isSelectionMode,
            ),
          ),
        ],
      ),
    );
  }
}
