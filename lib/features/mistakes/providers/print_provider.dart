import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'print_provider.g.dart';

/// 列印內容選項
enum PrintContentOption {
  questionOnly('只印題目', '適合自我測驗，重新作答'),
  questionAndAnswer('題目 + 答案', '快速複習用'),
  full('題目 + 答案 + AI解析', '完整版，適合深入理解'),
  withNote('題目 + 我的筆記', '包含個人筆記');

  final String title;
  final String subtitle;
  const PrintContentOption(this.title, this.subtitle);
}

/// 每頁題數
enum QuestionsPerPage {
  one(1, '1題/頁', '大字體，適合詳細閱讀'),
  two(2, '2題/頁', '適中，推薦使用'),
  four(4, '4題/頁', '省紙，適合快速瀏覽');

  final int count;
  final String title;
  final String subtitle;
  const QuestionsPerPage(this.count, this.title, this.subtitle);
}

/// 排序方式
enum SortOption {
  dateDesc('最新優先', Icons.arrow_downward),
  dateAsc('最舊優先', Icons.arrow_upward),
  category('依科目分類', Icons.category),
  errorCount('常錯優先', Icons.warning);

  final String title;
  final IconData icon;
  const SortOption(this.title, this.icon);
}

/// 列印設定狀態
class PrintSettings {
  final PrintContentOption contentOption;
  final QuestionsPerPage questionsPerPage;
  final SortOption sortOption;
  final bool includeImages;
  final bool showDate;

  const PrintSettings({
    this.contentOption = PrintContentOption.questionAndAnswer,
    this.questionsPerPage = QuestionsPerPage.two,
    this.sortOption = SortOption.dateDesc,
    this.includeImages = true,
    this.showDate = true,
  });

  PrintSettings copyWith({
    PrintContentOption? contentOption,
    QuestionsPerPage? questionsPerPage,
    SortOption? sortOption,
    bool? includeImages,
    bool? showDate,
  }) {
    return PrintSettings(
      contentOption: contentOption ?? this.contentOption,
      questionsPerPage: questionsPerPage ?? this.questionsPerPage,
      sortOption: sortOption ?? this.sortOption,
      includeImages: includeImages ?? this.includeImages,
      showDate: showDate ?? this.showDate,
    );
  }
}

/// 選取模式狀態
class SelectionState {
  final bool isSelectionMode;
  final Set<int> selectedIds;

  const SelectionState({
    this.isSelectionMode = false,
    this.selectedIds = const {},
  });

  SelectionState copyWith({
    bool? isSelectionMode,
    Set<int>? selectedIds,
  }) {
    return SelectionState(
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }

  int get selectedCount => selectedIds.length;
  bool isSelected(int id) => selectedIds.contains(id);
}

/// 選取模式 Notifier
@riverpod
class SelectionNotifier extends _$SelectionNotifier {
  @override
  SelectionState build() => const SelectionState();

  void enterSelectionMode() {
    state = state.copyWith(isSelectionMode: true);
  }

  void exitSelectionMode() {
    state = const SelectionState();
  }

  void toggleSelection(int id) {
    final newSet = Set<int>.from(state.selectedIds);
    if (newSet.contains(id)) {
      newSet.remove(id);
    } else {
      newSet.add(id);
    }
    state = state.copyWith(selectedIds: newSet);
  }

  void selectAll(List<int> ids) {
    state = state.copyWith(selectedIds: ids.toSet());
  }

  void clearSelection() {
    state = state.copyWith(selectedIds: {});
  }
}

/// 列印設定 Notifier
@riverpod
class PrintSettingsNotifier extends _$PrintSettingsNotifier {
  @override
  PrintSettings build() => const PrintSettings();

  void setContentOption(PrintContentOption option) {
    state = state.copyWith(contentOption: option);
  }

  void setQuestionsPerPage(QuestionsPerPage option) {
    state = state.copyWith(questionsPerPage: option);
  }

  void setSortOption(SortOption option) {
    state = state.copyWith(sortOption: option);
  }

  void setIncludeImages(bool value) {
    state = state.copyWith(includeImages: value);
  }

  void setShowDate(bool value) {
    state = state.copyWith(showDate: value);
  }

  void reset() {
    state = const PrintSettings();
  }
}
