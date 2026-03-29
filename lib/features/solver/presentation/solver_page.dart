import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_ux.dart';
import '../../../core/utils/latex_helper.dart';
import '../../../core/utils/paywall_gate.dart';
import '../../../core/services/gemini_service.dart' hide debugPrint;
import '../../../core/services/image_service.dart';
import '../../../core/utils/image_path_helper.dart';
import '../../../core/widgets/premium_image_viewer.dart';
import '../../camera/presentation/multi_crop_screen.dart';
import '../../mistakes/providers/mistakes_provider.dart';
import '../../subscription/providers/feature_trial_provider.dart';
import '../providers/solver_provider.dart' hide debugPrint;

/// 解題分析頁面
/// 使用 Riverpod 架構：UI 只用 ref.watch 觀察狀態
class SolverPage extends ConsumerStatefulWidget {
  final File? originalImage;
  final String? initialLatex;

  // 預解析的 Gemini 結果（如果已經從 AnalysisTask 解析完成）
  final String? subject; // 科目：數學、英文、國文、自然、地理、歷史、公民、其他
  final String? category; // 題型分類：一元一次方程式、平面幾何 等
  final String? gradeLevel; // 年級：國一、國二、高一 等
  final String? chapter; // 章節名稱
  final List<String>? keyConcepts;
  final List<Map<String, String>>? solutions;

  // 是否從錯題本進入（如果是，則不觸發 AI 分析，直接顯示本地數據）
  final bool isFromMistakes;
  final List<String>? savedSolutions; // 從錯題本讀取的解法列表

  // 新增：錯題 ID（如果從錯題本進入）
  final int? mistakeId;

  // 多題目模式：傳遞多個題目的數據，支持左右滑動
  final List<Map<String, dynamic>>?
      multipleProblems; // [{image, latex, subject, category, gradeLevel, chapter, keyConcepts, solutions}, ...]

  const SolverPage({
    super.key,
    this.originalImage,
    this.initialLatex,
    this.subject,
    this.category,
    this.gradeLevel,
    this.chapter,
    this.keyConcepts,
    this.solutions,
    this.isFromMistakes = false,
    this.savedSolutions,
    this.mistakeId,
    this.multipleProblems,
  });

  @override
  ConsumerState<SolverPage> createState() => _SolverPageState();
}

class _TutorChatMessage {
  const _TutorChatMessage({
    required this.role,
    required this.content,
  });

  final String role;
  final String content;

  bool get isUser => role == 'user';
}

class _SolverPageState extends ConsumerState<SolverPage> {
  bool _isSaved = false;
  bool _isRecoveringFullQuestionText = false;
  int _currentProblemIndex = 0; // 當前顯示的題目索引（用於多題目模式）
  late PageController _pageController;
  final TextEditingController _tutorController = TextEditingController();
  final List<_TutorChatMessage> _tutorMessages = <_TutorChatMessage>[];
  bool _isTutorLoading = false;
  // 多題目模式下，記錄每個題目是否已保存
  final Set<int> _savedProblemIndices = <int>{};
  // 多題目模式下，記錄每個題目的標籤編輯狀態（用於臨時編輯）
  final Map<int, List<String>> _editedKeyConcepts = <int, List<String>>{};
  // 多題目模式下，記錄每個題目的科目/分類編輯狀態
  final Map<int, String> _editedSubjects = <int, String>{};
  final Map<int, String> _editedCategories = <int, String>{};
  // 記錄原始值，用於檢測是否有修改
  String? _originalSubject;
  String? _originalCategory;
  List<String>? _originalKeyConcepts;

  @override
  void initState() {
    super.initState();
    // 初始化 PageController（用於多題目滑動）
    final initialPage =
        widget.multipleProblems != null && widget.multipleProblems!.isNotEmpty
            ? 0
            : _currentProblemIndex;
    _pageController = PageController(
      initialPage: initialPage,
    );

    // 頁面載入時先重置狀態，然後啟動分析流程
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 確保 widget 仍然 mounted
      if (!mounted) return;

      try {
        // 先重置狀態，確保每次進入頁面都是乾淨的狀態
        ref.read(solverNotifierProvider.notifier).reset();

        // 多題目模式：載入第一個題目
        if (widget.multipleProblems != null &&
            widget.multipleProblems!.isNotEmpty) {
          _loadProblemAtIndex(0);
          return;
        }

        // 如果從錯題本進入，直接顯示本地數據，不觸發 AI 分析
        if (widget.isFromMistakes) {
          // 記錄原始值，用於檢測是否有修改
          _originalSubject = widget.subject;
          _originalCategory = widget.category;
          _originalKeyConcepts = List<String>.from(widget.keyConcepts ?? []);

          final solverNotifier = ref.read(solverNotifierProvider.notifier);
          // 將保存的解法轉換為 SolutionItem
          final solutionItems = widget.savedSolutions?.map((solution) {
                // 嘗試解析解法格式：可能是 "標題：內容" 或純內容
                final trimmedSolution = solution.trim();
                if (trimmedSolution.contains('：')) {
                  final colonIndex = trimmedSolution.indexOf('：');
                  final title = trimmedSolution.substring(0, colonIndex).trim();
                  final content = colonIndex < trimmedSolution.length - 1
                      ? trimmedSolution.substring(colonIndex + 1).trim()
                      : trimmedSolution;
                  return SolutionItem(
                    title: title.isNotEmpty ? title : '解法',
                    content: content,
                  );
                } else {
                  return SolutionItem(
                    title: '解法',
                    content: trimmedSolution,
                  );
                }
              }).toList() ??
              [];

          solverNotifier.setPreParsedResult(
            recognizedLatex: widget.initialLatex,
            subject: widget.subject,
            category: widget.category,
            gradeLevel: widget.gradeLevel,
            chapter: widget.chapter,
            keyConcepts: widget.keyConcepts ?? [],
            solutions: solutionItems,
          );
          _recoverFullQuestionTextIfNeeded();
          return; // 不觸發 AI 分析
        }

        // 如果已經有預解析的 Gemini 結果，直接使用，不需要重新解析
        if (widget.solutions != null && widget.solutions!.isNotEmpty) {
          final solverNotifier = ref.read(solverNotifierProvider.notifier);
          // 直接設置為完成狀態，使用預解析的結果
          solverNotifier.setPreParsedResult(
            recognizedLatex: widget.initialLatex,
            subject: widget.subject,
            category: widget.category,
            gradeLevel: widget.gradeLevel,
            chapter: widget.chapter,
            keyConcepts: widget.keyConcepts ?? [],
            solutions: widget.solutions!
                .map((s) => SolutionItem(
                      title: s['title'] ?? '解法',
                      content: s['content'] ?? '',
                    ))
                .toList(),
          );
        } else if (widget.originalImage != null ||
            (widget.initialLatex != null && widget.initialLatex!.isNotEmpty)) {
          // 如果沒有預解析結果，則啟動分析流程
          ref.read(solverNotifierProvider.notifier).startAnalysis(
                imageFile: widget.originalImage,
                initialLatex: widget.initialLatex,
                forceRestart: true,
              );
        }
      } catch (e) {
        debugPrint("⚠️ SolverPage initState 錯誤: $e");
      }
    });
  }

  Future<void> _recoverFullQuestionTextIfNeeded() async {
    if (_isRecoveringFullQuestionText) return;
    final initialLatex = widget.initialLatex?.trim();
    if (!widget.isFromMistakes ||
        widget.mistakeId == null ||
        widget.originalImage == null ||
        initialLatex == null ||
        initialLatex.isEmpty ||
        !initialLatex.endsWith('...')) {
      return;
    }

    _isRecoveringFullQuestionText = true;
    try {
      final fullQuestionText =
          await GeminiService().recognizeImage(widget.originalImage!);
      if (!mounted ||
          fullQuestionText == null ||
          fullQuestionText.trim().isEmpty) {
        return;
      }

      final normalized = fullQuestionText.trim();
      if (normalized == initialLatex) {
        return;
      }

      ref
          .read(solverNotifierProvider.notifier)
          .updateRecognizedLatex(normalized);
      await ref.read(mistakesProvider.notifier).updateMistakeTitle(
            id: widget.mistakeId!,
            title: normalized,
          );
    } catch (_) {
      // 靜默失敗：保留原本已存資料，避免影響使用者操作
    } finally {
      _isRecoveringFullQuestionText = false;
    }
  }

  @override
  void dispose() {
    _tutorController.dispose();
    _pageController.dispose();
    // 不需要在 dispose 中重置狀態，因為：
    // 1. 每次進入頁面時 initState 都會重置並重新開始分析
    // 2. dispose 階段 ref 可能已經不可用，會導致錯誤
    // 3. Provider 會在沒有監聽者時自動清理
    super.dispose();
  }

  /// 監聽 subject 和 category 的變化，如果有 mistakeId 則更新資料庫
  void _handleSubjectOrCategoryChange({bool immediate = false}) {
    final solverState = ref.read(solverNotifierProvider);
    final currentSubject = solverState.subject ?? '其他';
    final currentCategory = solverState.category ?? '其他';

    // 如果從錯題本進入，且有修改，則更新資料庫
    if (widget.isFromMistakes &&
        widget.mistakeId != null &&
        (currentSubject != _originalSubject ||
            currentCategory != _originalCategory)) {
      if (immediate) {
        // 立即保存（subject 修改時）
        if (mounted) {
          ref.read(mistakesProvider.notifier).updateMistakeSubjectAndCategory(
                id: widget.mistakeId!,
                subject: currentSubject,
                category: currentCategory,
              );
        }
      } else {
        // 延遲更新（category 修改時，避免頻繁更新）
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ref.read(mistakesProvider.notifier).updateMistakeSubjectAndCategory(
                  id: widget.mistakeId!,
                  subject: currentSubject,
                  category: currentCategory,
                );
          }
        });
      }
    }
  }

  /// 保存所有標籤到資料庫（subject、category、keyConcepts）
  void _saveAllTagsToDatabase() {
    if (!widget.isFromMistakes || widget.mistakeId == null) {
      return;
    }

    final solverState = ref.read(solverNotifierProvider);
    final currentSubject = solverState.subject ?? '其他';
    final currentCategory = solverState.category ?? '一般';
    final currentKeyConcepts = solverState.keyConcepts;

    // 檢查是否有任何修改（處理 null 情況）
    final hasSubjectChange = currentSubject != (_originalSubject ?? '其他');
    final hasCategoryChange = currentCategory != (_originalCategory ?? '一般');
    final hasKeyConceptsChange =
        !_listsEqual(currentKeyConcepts, _originalKeyConcepts ?? []);

    if (hasSubjectChange || hasCategoryChange || hasKeyConceptsChange) {
      // 構建新的 tags（包含 chapter 和 keyConcepts，過濾掉「AI 解析」）
      final newTags = <String>[
        'AI 解析',
        if (solverState.chapter != null) solverState.chapter!,
        ...currentKeyConcepts.where((c) => c != 'AI 解析').take(5),
      ];

      try {
        ref.read(mistakesProvider.notifier).updateMistakeTags(
              id: widget.mistakeId!,
              subject: currentSubject,
              category: currentCategory,
              tags: newTags,
              chapter: solverState.chapter,
            );
      } catch (e) {
        debugPrint("   ❌ 保存失敗: $e");
      }
    }
  }

  /// 輔助方法：比較兩個列表是否相等
  bool _listsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  Future<void> _toggleSave() async {
    final solverState = ref.read(solverNotifierProvider);

    if (_isSaved) {
      AppUX.feedbackSelection();
      setState(() => _isSaved = false);
      return;
    }

    if (widget.originalImage == null || solverState.recognizedLatex == null) {
      AppUX.showSnackBar(context, "無法保存：缺少題目資料", isError: true);
      return;
    }

    AppUX.feedbackClick();

    try {
      // 先將圖片複製到永久的錯題圖片資料夾，避免暫存圖片被系統清除
      final permanentPath =
          await ImagePathHelper.saveImage(widget.originalImage!);

      // 將解法轉為字串列表
      final solutionStrings =
          solverState.solutions.map((s) => "${s.title}：${s.content}").toList();

      await ref.read(mistakesProvider.notifier).addMistake(
            imagePath: permanentPath,
            title: solverState.recognizedLatex!,
            tags: [
              'AI 解析',
              if (solverState.chapter != null) solverState.chapter!,
              ...solverState.keyConcepts.where((c) => c != 'AI 解析').take(5),
            ],
            solutions: solutionStrings,
            subject: solverState.subject ?? '其他',
            category: solverState.category ?? '一般',
            chapter: solverState.chapter,
          );

      if (mounted) {
        setState(() => _isSaved = true);
        AppUX.feedbackSuccess();
        AppUX.showSnackBar(context, "已加入錯題本");
      }
    } catch (e) {
      debugPrint("保存錯題失敗: $e");
      if (mounted) {
        AppUX.showSnackBar(context, "保存失敗，請重試", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 使用 ref.watch 觀察狀態變化
    final solverState = ref.watch(solverNotifierProvider);

    // 判斷是否為空狀態（顯示「錯題解析高手」歡迎頁面）
    final isEmptyState = widget.originalImage == null &&
        widget.initialLatex == null &&
        (widget.multipleProblems == null || widget.multipleProblems!.isEmpty);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        // 頁面返回時保存所有編輯的標籤
        _saveAllTagsToDatabase();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // 空狀態時隱藏 AppBar
        appBar: isEmptyState
            ? null
            : AppBar(
                // 如果是 tab 模式（無法 pop），則不顯示 title
                title: Navigator.of(context).canPop()
                    ? Text(_getAppBarTitle(solverState))
                    : null,
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                // 始終顯示返回按鈕，即使無法 pop 也能返回到主頁
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () {
                    if (!mounted) return;
                    final navigator = Navigator.of(context);

                    AppUX.feedbackClick();

                    // 頁面返回前保存所有編輯的標籤
                    _saveAllTagsToDatabase();

                    // 如果可以 pop（從其他頁面 push 進來），則 pop
                    if (navigator.canPop()) {
                      navigator.pop(); // Pop SolverPage

                      // 如果還有其他頁面（如 AnalysisProgressPage），繼續 pop
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted && navigator.canPop()) {
                          navigator.popUntil((route) => route.isFirst);
                        }
                      });
                    } else {
                      // 如果無法 pop（如在 tab 模式下），則返回到第一個路由（主頁）
                      navigator.popUntil((route) => route.isFirst);
                    }
                  },
                ),
                automaticallyImplyLeading: false,
              ),
        body: _buildBody(solverState),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _buildFab(solverState),
      ),
    );
  }

  String _getAppBarTitle(SolverResult state) {
    if (state.gradeLevel != null && state.chapter != null) {
      return "${state.gradeLevel} • ${state.chapter}";
    }
    return "AI 解題分析";
  }

  Widget _buildBody(SolverResult state) {
    // 多題目模式：使用 PageView 支持左右滑動
    if (widget.multipleProblems != null &&
        widget.multipleProblems!.isNotEmpty) {
      return Column(
        children: [
          // PageView 用於左右滑動
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentProblemIndex = index;
                });
                // 更新當前題目的狀態
                _loadProblemAtIndex(index);
              },
              itemCount: widget.multipleProblems!.length,
              itemBuilder: (context, index) {
                return _buildSingleProblemView(index);
              },
            ),
          ),

          // 題目指示器（例如：1/3）- 移到最下面
          _buildProblemIndicator(),
        ],
      );
    }

    // 單題目模式：原有的顯示邏輯
    // 空狀態
    if (widget.originalImage == null && widget.initialLatex == null) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 題目預覽區
          _buildProblemPreview(state),

          const SizedBox(height: 24),

          // 2. 題目資訊卡片（年級、章節、核心觀念）
          if (state.status == SolverStatus.completed) ...[
            // 只要有 subject、category、gradeLevel、chapter 或 keyConcepts 其中一個有值就顯示
            if (state.subject != null ||
                state.category != null ||
                state.gradeLevel != null ||
                state.chapter != null ||
                state.keyConcepts.isNotEmpty)
              _buildProblemInfoCard(state),
            if (state.subject != null ||
                state.category != null ||
                state.gradeLevel != null ||
                state.chapter != null ||
                state.keyConcepts.isNotEmpty)
              const SizedBox(height: 24),
          ],

          // 3. 解法區（標題和加入錯題本按鈕在同一行）
          _buildSolutionHeader(state),
          const SizedBox(height: 16),

          _buildSolutionArea(state),

          if (state.status == SolverStatus.completed) ...[
            const SizedBox(height: 24),
            _buildTutorSection(state),
          ],

          const SizedBox(height: 20), // 移除底部留白，因為 FAB 已經移到標題旁
        ],
      ),
    );
  }

  /// 題目指示器（顯示當前是第幾個題目）
  Widget _buildProblemIndicator() {
    if (widget.multipleProblems == null || widget.multipleProblems!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 左箭頭
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            onPressed: _currentProblemIndex > 0
                ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
          ),

          // 題目計數
          Text(
            "${_currentProblemIndex + 1} / ${widget.multipleProblems!.length}",
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),

          // 右箭頭
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
            onPressed:
                _currentProblemIndex < widget.multipleProblems!.length - 1
                    ? () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
          ),
        ],
      ),
    );
  }

  /// 載入指定索引的題目數據
  void _loadProblemAtIndex(int index) {
    if (widget.multipleProblems == null ||
        index >= widget.multipleProblems!.length) {
      return;
    }

    final problem = widget.multipleProblems![index];
    final solverNotifier = ref.read(solverNotifierProvider.notifier);

    // 轉換解法格式
    final solutions = (problem['solutions'] as List<dynamic>?)?.map((s) {
          if (s is Map<String, dynamic>) {
            return SolutionItem(
              title: s['title']?.toString() ?? '解法',
              content: s['content']?.toString() ?? '',
            );
          } else if (s is String) {
            // 如果是字符串格式 "標題：內容"
            if (s.contains('：')) {
              final colonIndex = s.indexOf('：');
              return SolutionItem(
                title: s.substring(0, colonIndex).trim(),
                content: colonIndex < s.length - 1
                    ? s.substring(colonIndex + 1).trim()
                    : s,
              );
            } else {
              return SolutionItem(title: '解法', content: s);
            }
          }
          return SolutionItem(title: '解法', content: s.toString());
        }).toList() ??
        [];

    solverNotifier.setPreParsedResult(
      recognizedLatex: problem['latex']?.toString(),
      subject: problem['subject']?.toString(),
      gradeLevel: problem['gradeLevel']?.toString(),
      category: problem['category']?.toString(),
      chapter: problem['chapter']?.toString(),
      keyConcepts: (problem['keyConcepts'] as List<dynamic>?)
              ?.map((c) => c.toString())
              .toList() ??
          [],
      solutions: solutions,
    );
  }

  /// 構建單個題目的視圖（用於 PageView）
  Widget _buildSingleProblemView(int index) {
    if (widget.multipleProblems == null ||
        index >= widget.multipleProblems!.length) {
      return const Center(child: Text("題目數據錯誤"));
    }

    final problem = widget.multipleProblems![index];

    // 獲取圖片
    File? imageFile;
    if (problem['image'] != null) {
      if (problem['image'] is File) {
        imageFile = problem['image'] as File;
      } else {
        final imagePath = problem['image'].toString();
        imageFile = File(imagePath);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 題目預覽區
          _buildProblemPreviewForMulti(imageFile, problem['latex']?.toString()),

          const SizedBox(height: 24),

          // 2. 題目資訊卡片
          // 只要有 subject、category、gradeLevel、chapter 或 keyConcepts 其中一個有值就顯示
          if (problem['subject'] != null ||
              problem['category'] != null ||
              problem['gradeLevel'] != null ||
              problem['chapter'] != null ||
              (problem['keyConcepts'] as List?)?.isNotEmpty == true)
            _buildProblemInfoCardForMulti(problem, index),

          if (problem['subject'] != null ||
              problem['category'] != null ||
              problem['gradeLevel'] != null ||
              problem['chapter'] != null ||
              (problem['keyConcepts'] as List?)?.isNotEmpty == true)
            const SizedBox(height: 24),

          // 3. 解法區（標題和加入錯題本按鈕在同一行）
          _buildSolutionHeaderForMulti(index),
          const SizedBox(height: 16),

          _buildSolutionAreaForMulti(problem),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// 為多題目模式構建題目預覽
  Widget _buildProblemPreviewForMulti(File? imageFile, String? latex) {
    final heroTag =
        'problem_image_${_currentProblemIndex}_${imageFile?.path ?? 'none'}';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 上方圖片（顯示完整圖片，可點擊查看）
          if (imageFile != null)
            InkWell(
              onTap: () {
                AppUX.feedbackClick();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PremiumImageViewer(
                      imagePath: imageFile.path,
                      heroTag: heroTag,
                    ),
                  ),
                );
              },
              child: Hero(
                tag: heroTag,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Image.file(
                          imageFile,
                          fit: BoxFit.contain,
                        ),
                      ),
                      // 點擊提示圖標
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 下方辨識結果
          Padding(
            padding: const EdgeInsets.all(16),
            child: latex != null && latex.isNotEmpty
                ? LatexText(
                    text: LatexHelper.cleanOcrText(latex),
                    fontSize: 14,
                    lineHeight: 1.6,
                  )
                : const Text(
                    "無法識別題目",
                    style: TextStyle(color: Colors.grey),
                  ),
          ),
        ],
      ),
    );
  }

  /// 為多題目模式構建題目資訊卡片
  Widget _buildProblemInfoCardForMulti(
      Map<String, dynamic> problem, int problemIndex) {
    final subject = _editedSubjects[problemIndex] ??
        (problem['subject']?.toString() ?? '其他');
    final category = _editedCategories[problemIndex] ??
        (problem['category']?.toString() ?? '其他');
    final originalKeyConcepts = (problem['keyConcepts'] as List<dynamic>?)
            ?.map((c) => c.toString())
            .toList() ??
        [];
    final keyConcepts = _editedKeyConcepts[problemIndex] ?? originalKeyConcepts;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 簡化標籤顯示：科目和題型分類
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 科目 - 橘色
              InkWell(
                onTap: () {
                  AppUX.feedbackClick();
                  _showSubjectDialogForMulti(context, problemIndex);
                },
                borderRadius: BorderRadius.circular(8),
                child: _buildInfoChip(
                  icon: Icons.menu_book_outlined,
                  label: subject,
                  color: const Color(0xFFFF9800),
                ),
              ),
              // 題型分類 - 藍色
              InkWell(
                onTap: () {
                  AppUX.feedbackClick();
                  _showCategoryDialogForMulti(context, problemIndex);
                },
                borderRadius: BorderRadius.circular(8),
                child: _buildInfoChip(
                  icon: Icons.label_outline,
                  label: category,
                  color: const Color(0xFF2196F3),
                ),
              ),
            ],
          ),
          // 上方標籤和下方核心觀念之間增加間距
          const SizedBox(height: 16),

          // 核心觀念（過濾掉「AI 解析」）
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (keyConcepts
                        .where((concept) => concept != 'AI 解析')
                        .isNotEmpty) ...[
                      const Text(
                        "核心觀念",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: keyConcepts
                            .where((concept) => concept != 'AI 解析')
                            .map((concept) =>
                                _buildConceptTag(concept, onDelete: () {
                                  AppUX.feedbackClick();
                                  final currentIndex = _currentProblemIndex;
                                  final currentConcepts = List<String>.from(
                                      _editedKeyConcepts[currentIndex] ??
                                          keyConcepts);
                                  currentConcepts.remove(concept);
                                  setState(() {
                                    _editedKeyConcepts[currentIndex] =
                                        currentConcepts;
                                  });
                                }))
                            .toList(),
                      ),
                    ] else ...[
                      const Text(
                        "核心觀念",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              // 新增標籤按鈕
              InkWell(
                onTap: () {
                  AppUX.feedbackClick();
                  _showAddTagDialogForMulti(context, _currentProblemIndex);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: const Color(0xFF1976D2), width: 1.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: Color(0xFF1976D2)),
                      SizedBox(width: 4),
                      Text(
                        "新增",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 為多題目模式構建解法標題和加入錯題本按鈕
  Widget _buildSolutionHeaderForMulti(int problemIndex) {
    if (widget.multipleProblems == null ||
        problemIndex >= widget.multipleProblems!.length) {
      return const Text(
        "AI 深度解析",
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      );
    }

    final problem = widget.multipleProblems![problemIndex];
    // 檢查是否有解法數據
    final hasSolutions =
        (problem['solutions'] as List<dynamic>?)?.isNotEmpty ?? false;
    // 多題目模式下，只要有解法數據就可以保存
    final canSave = hasSolutions;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          "AI 深度解析",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (canSave)
          TextButton.icon(
            onPressed: () => _toggleSaveForMulti(problemIndex),
            icon: Icon(
              _savedProblemIndices.contains(problemIndex)
                  ? Icons.check_circle
                  : Icons.bookmark_border,
              size: 18,
              color: _savedProblemIndices.contains(problemIndex)
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
            ),
            label: Text(
              _savedProblemIndices.contains(problemIndex) ? "已加入" : "加入錯題本",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _savedProblemIndices.contains(problemIndex)
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  /// 為多題目模式保存錯題
  Future<void> _toggleSaveForMulti(int problemIndex) async {
    if (widget.multipleProblems == null ||
        problemIndex >= widget.multipleProblems!.length) {
      return;
    }

    final problem = widget.multipleProblems![problemIndex];

    // 檢查是否已經保存過
    if (_savedProblemIndices.contains(problemIndex)) {
      AppUX.feedbackSelection();
      setState(() {
        _savedProblemIndices.remove(problemIndex);
      });
      return;
    }

    AppUX.feedbackClick();

    try {
      // 獲取圖片
      File? imageFile;
      if (problem['image'] != null) {
        if (problem['image'] is File) {
          imageFile = problem['image'] as File;
        } else {
          final imagePath = problem['image'].toString();
          imageFile = File(imagePath);
        }
      }

      if (imageFile == null) {
        AppUX.showSnackBar(context, "無法保存：圖片不存在", isError: true);
        return;
      }

      // 先將圖片複製到永久的錯題圖片資料夾，避免暫存圖片被系統清除
      final permanentPath = await ImagePathHelper.saveImage(imageFile);

      // 從 problem 中獲取解法數據
      final solutions = (problem['solutions'] as List<dynamic>?) ?? [];
      final solutionStrings = solutions.map((s) {
        if (s is Map<String, dynamic>) {
          return "${s['title'] ?? '解法'}：${s['content'] ?? ''}";
        } else if (s is String) {
          return s;
        }
        return s.toString();
      }).toList();

      // 從 problem 中獲取其他數據
      final latex = problem['latex']?.toString() ?? '';
      final chapter = problem['chapter']?.toString();
      final originalKeyConcepts = (problem['keyConcepts'] as List<dynamic>?)
              ?.map((c) => c.toString())
              .toList() ??
          [];
      final keyConcepts =
          _editedKeyConcepts[problemIndex] ?? originalKeyConcepts;
      final subject = _editedSubjects[problemIndex] ??
          (problem['subject']?.toString() ?? '其他');
      final category = _editedCategories[problemIndex] ??
          (problem['category']?.toString() ?? '一般');

      ref.read(mistakesProvider.notifier).addMistake(
            imagePath: permanentPath,
            title: latex.isNotEmpty ? latex : '題目 ${problemIndex + 1}',
            tags: [
              'AI 解析',
              if (chapter != null) chapter,
              ...keyConcepts.where((c) => c != 'AI 解析').take(5),
            ],
            solutions: solutionStrings,
            subject: subject,
            category: category,
            chapter: chapter,
          );

      if (mounted) {
        setState(() {
          _savedProblemIndices.add(problemIndex);
        });
        AppUX.feedbackSuccess();
        AppUX.showSnackBar(context, "已加入錯題本");
      }
    } catch (e) {
      debugPrint("保存錯題失敗: $e");
      if (mounted) {
        AppUX.showSnackBar(context, "保存失敗，請重試", isError: true);
      }
    }
  }

  /// 為多題目模式構建解法區域
  Widget _buildSolutionAreaForMulti(Map<String, dynamic> problem) {
    final solutions = (problem['solutions'] as List<dynamic>?)?.map((s) {
          if (s is Map<String, dynamic>) {
            return SolutionItem(
              title: s['title']?.toString() ?? '解法',
              content: s['content']?.toString() ?? '',
            );
          } else if (s is String) {
            if (s.contains('：')) {
              final colonIndex = s.indexOf('：');
              return SolutionItem(
                title: s.substring(0, colonIndex).trim(),
                content: colonIndex < s.length - 1
                    ? s.substring(colonIndex + 1).trim()
                    : s,
              );
            } else {
              return SolutionItem(title: '解法', content: s);
            }
          }
          return SolutionItem(title: '解法', content: s.toString());
        }).toList() ??
        [];

    if (solutions.isEmpty) {
      return const Center(child: Text("暫無解法資料"));
    }

    return Column(
      children:
          solutions.map((solution) => _buildSolutionCard(solution)).toList(),
    );
  }

  Widget _buildProblemPreview(SolverResult state) {
    final heroTag =
        'problem_image_single_${widget.originalImage?.path ?? 'none'}';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 上方圖片（顯示完整圖片，可點擊查看）
          if (widget.originalImage != null)
            InkWell(
              onTap: () {
                AppUX.feedbackClick();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PremiumImageViewer(
                      imagePath: widget.originalImage!.path,
                      heroTag: heroTag,
                    ),
                  ),
                );
              },
              child: Hero(
                tag: heroTag,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Image.file(
                          widget.originalImage!,
                          fit: BoxFit.contain,
                        ),
                      ),
                      // 點擊提示圖標
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 下方辨識結果
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildRecognizedText(state),
          ),
        ],
      ),
    );
  }

  Widget _buildRecognizedText(SolverResult state) {
    if (state.status == SolverStatus.ocr) {
      return _buildShimmerLoading("AI 正在辨識題目...");
    }

    // 獲取並清理 OCR 結果
    final rawText = state.recognizedLatex ?? widget.initialLatex ?? "";
    final cleanedText = LatexHelper.cleanOcrText(rawText);

    if (state.status == SolverStatus.thinking) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (cleanedText.isNotEmpty) _buildQuestionText(cleanedText),
          const SizedBox(height: 8),
          const Text(
            "✨ AI 正在思考解法...",
            style: TextStyle(color: Colors.orange, fontSize: 12),
          ),
        ],
      );
    }

    // 顯示清理後的辨識結果
    if (cleanedText.isNotEmpty) {
      final canEditTitle = widget.isFromMistakes &&
          widget.mistakeId != null &&
          state.status == SolverStatus.completed;
      if (!canEditTitle) {
        return _buildQuestionText(cleanedText);
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildQuestionText(cleanedText)),
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              size: 18,
              color: Colors.grey,
            ),
            tooltip: '編輯題目',
            onPressed: () => _showEditTitleDialog(cleanedText),
          ),
        ],
      );
    }

    return const Text(
      "無法識別題目",
      style: TextStyle(color: Colors.grey),
    );
  }

  /// 題目文字區塊：不限制高度，讓整頁一起滾動顯示完整題目
  Widget _buildQuestionText(String text) {
    return LatexText(
      text: text,
      fontSize: 14,
      lineHeight: 1.6,
    );
  }

  Future<void> _showEditTitleDialog(String currentTitle) async {
    if (widget.mistakeId == null) return;

    final initialEditableTitle = LatexHelper.toReadableText(currentTitle);
    final controller = TextEditingController(text: initialEditableTitle);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("編輯題目"),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: "輸入題目內容...",
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) async {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              ref
                  .read(solverNotifierProvider.notifier)
                  .updateRecognizedLatex(value);
              await ref.read(mistakesProvider.notifier).updateMistakeTitle(
                    id: widget.mistakeId!,
                    title: value,
                  );
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("取消"),
            ),
            TextButton(
              onPressed: () async {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  AppUX.showSnackBar(context, "題目不能為空", isError: true);
                  return;
                }
                if (value == initialEditableTitle) {
                  Navigator.of(dialogContext).pop();
                  return;
                }

                ref
                    .read(solverNotifierProvider.notifier)
                    .updateRecognizedLatex(value);
                await ref.read(mistakesProvider.notifier).updateMistakeTitle(
                      id: widget.mistakeId!,
                      title: value,
                    );
                if (!mounted || !dialogContext.mounted) return;
                AppUX.showSnackBar(context, "題目已更新");
                Navigator.of(dialogContext).pop();
              },
              child: const Text("儲存"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSolutionArea(SolverResult state) {
    switch (state.status) {
      case SolverStatus.idle:
      case SolverStatus.ocr:
        return _buildSolutionSkeleton();
      case SolverStatus.thinking:
        return _buildThinkingSkeleton();
      case SolverStatus.failed:
        return _buildErrorCard(state.errorMessage ?? "發生未知錯誤");
      case SolverStatus.completed:
        if (state.solutions.isEmpty) {
          return const Center(child: Text("暫無解法資料"));
        }
        return Column(
          children: state.solutions
              .map((solution) => _buildSolutionCard(solution))
              .toList(),
        );
    }
  }

  Future<void> _submitTutorQuestion(
    SolverResult state, {
    String? presetQuestion,
  }) async {
    final question = (presetQuestion ?? _tutorController.text).trim();
    if (question.isEmpty || _isTutorLoading) return;

    FocusScope.of(context).unfocus();
    if (presetQuestion == null) {
      _tutorController.clear();
    }

    setState(() {
      _tutorMessages.add(_TutorChatMessage(role: 'user', content: question));
      _isTutorLoading = true;
    });

    final reply = await GeminiService().askTutorFollowUp(
      questionText: state.recognizedLatex ?? widget.initialLatex ?? '',
      studentQuestion: question,
      subject: state.subject,
      category: state.category,
      chapter: state.chapter,
      keyConcepts: state.keyConcepts.where((item) => item != 'AI 解析').toList(),
      solutions: state.solutions
          .map((solution) => {
                'title': solution.title,
                'content': solution.content,
              })
          .toList(),
      history: _tutorMessages
          .map((message) => {
                'role': message.role,
                'content': message.content,
              })
          .toList(),
    );

    if (!mounted) return;
    setState(() {
      _tutorMessages.add(
        _TutorChatMessage(
          role: 'assistant',
          content: reply?.trim().isNotEmpty == true
              ? reply!.trim()
              : '這次沒有成功回覆，你可以換個問法再問一次。',
        ),
      );
      _isTutorLoading = false;
    });
  }

  Widget _buildTutorSection(SolverResult state) {
    final quickQuestions = [
      '這一步為什麼可以這樣做？',
      '有沒有更快的方法？',
      '這題最容易錯在哪裡？',
      '幫我用更簡單的方式重講一次',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  color: Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 互動問答',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '看不懂哪一步，就直接追問。',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickQuestions
                .map(
                  (question) => ActionChip(
                    label: Text(question),
                    backgroundColor: const Color(0xFFF5F7FF),
                    side: const BorderSide(color: Color(0xFFDCE3FF)),
                    onPressed: _isTutorLoading
                        ? null
                        : () => _submitTutorQuestion(
                              state,
                              presetQuestion: question,
                            ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          if (_tutorMessages.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                '你可以問：這一步為什麼要移項？為什麼這裡可以約分？這題有沒有更快的判斷方式？',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            )
          else
            Column(
              children: _tutorMessages
                  .map((message) => _buildTutorMessageBubble(message))
                  .toList(),
            ),
          if (_isTutorLoading) ...[
            const SizedBox(height: 12),
            _buildTutorLoadingBubble(),
          ],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _tutorController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: '輸入你看不懂的地方...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _submitTutorQuestion(state),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed:
                    _isTutorLoading ? null : () => _submitTutorQuestion(state),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(52, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTutorMessageBubble(_TutorChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser
                      ? const Color(0xFF1F2937)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isUser
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: isUser
                    ? Text(
                        message.content,
                        style: const TextStyle(
                          color: Colors.white,
                          height: 1.55,
                        ),
                      )
                    : LatexText(
                        text: message.content,
                        fontSize: 14,
                        lineHeight: 1.7,
                        textColor: AppColors.textPrimary,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              'AI 老師正在整理回答...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolutionCard(SolutionItem solution) {
    // 根據標題選擇顏色和樣式
    Color tagColor = const Color(0xFF2196F3);
    IconData tagIcon = Icons.lightbulb_outline;
    Color backgroundColor = const Color(0xFFF5F9FF);
    Color iconBackgroundColor = const Color(0xFFE3F2FD);

    if (solution.title.contains("速解") || solution.title.contains("技巧")) {
      tagColor = const Color(0xFFFF9800);
      backgroundColor = const Color(0xFFFFF8F0);
      iconBackgroundColor = const Color(0xFFFFE0B2);
      tagIcon = Icons.flash_on;
    } else if (solution.title.contains("易錯") || solution.title.contains("提醒")) {
      tagColor = const Color(0xFFE91E63);
      backgroundColor = const Color(0xFFFFF0F5);
      iconBackgroundColor = const Color(0xFFF8BBD0);
      tagIcon = Icons.warning_amber_rounded;
    } else if (solution.title.contains("標準") || solution.title.contains("解法")) {
      tagColor = const Color(0xFF2196F3);
      backgroundColor = const Color(0xFFF5F9FF);
      iconBackgroundColor = const Color(0xFFE3F2FD);
      tagIcon = Icons.school_outlined;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            offset: const Offset(0, 2),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題區域（帶背景色和圖標）
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 圖標
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    tagIcon,
                    color: tagColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                // 標題
                Expanded(
                  child: Text(
                    LatexHelper.toReadableText(
                      solution.title,
                      fallback: '解法',
                    ),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: tagColor,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 內容區域（帶內邊距和分隔線，讓整頁一起滾動）
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: backgroundColor.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: _buildFormattedContent(solution.content),
          ),
        ],
      ),
    );
  }

  /// 格式化解題內容，改善可讀性
  Widget _buildFormattedContent(String content) {
    if (content.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            "暫無解題內容",
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    // 清理內容，移除多餘的空白和換行
    String cleanedContent = content.trim();

    // 如果內容看起來像 JSON 格式，嘗試提取實際內容
    // 這是一個備用方案，以防 JSON 解析失敗
    if (cleanedContent.contains('"grade_level"') ||
        cleanedContent.contains('"solutions"') ||
        cleanedContent.contains('"content"')) {
      debugPrint("⚠️ 檢測到 JSON 格式的內容，嘗試提取實際內容");
      // 嘗試提取 "content" 字段的值
      try {
        final contentMatch =
            RegExp(r'"content"\s*:\s*"([^"]+)"').firstMatch(cleanedContent);
        if (contentMatch != null) {
          cleanedContent = contentMatch.group(1) ?? cleanedContent;
          debugPrint("✅ 成功提取內容");
        }
      } catch (e) {
        debugPrint("❌ 提取內容失敗: $e");
      }
    }

    // 🔧 修復亂碼：移除重複的題目文字和原始 LaTeX 標記
    // 移除以題目開頭模式的重複行（例如："()5、計算:"、"題目:" 等）
    final lines = cleanedContent.split('\n');
    final filteredLines = <String>[];
    bool foundSolutionStart = false; // 標記是否已找到解法開始

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) {
        // 保留空行（用於段落分隔），但避免連續多個空行
        if (filteredLines.isNotEmpty &&
            filteredLines.last.isNotEmpty &&
            filteredLines.last.trim().isNotEmpty) {
          filteredLines.add('');
        }
        continue;
      }

      // 跳過重複的題目開頭模式（只有在解法開始前才過濾）
      // 匹配模式：()數字、計算: / 題目: / 計算: / 等等，且後面跟著 LaTeX 標記或很短
      if (!foundSolutionStart) {
        final isProblemPattern = RegExp(
                r'^[（(]?\)?\d+[）)、，,：:]\s*(計算|題目|求|若|設)',
                caseSensitive: false)
            .hasMatch(trimmedLine);

        // 如果這行是題目模式，且後面跟著原始 LaTeX 標記（如 \[ 或 \(），則跳過
        if (isProblemPattern &&
            (trimmedLine.contains(r'\[') || trimmedLine.contains(r'\(')) &&
            trimmedLine.length < 200) {
          debugPrint(
              "🔧 移除重複的題目文字: ${trimmedLine.substring(0, math.min(50, trimmedLine.length))}...");
          continue;
        }

        // 跳過只包含原始 LaTeX 標記的行（看起來像是題目重複，且沒有解法關鍵詞）
        if (RegExp(r'^.*?\\?[\[\(]').hasMatch(trimmedLine) &&
            trimmedLine.length < 100 &&
            !RegExp(r'[一-龠]').hasMatch(trimmedLine)) {
          // 如果這行看起來像是純 LaTeX 標記（沒有實際解法內容），跳過它
          if (!trimmedLine.contains('理由') &&
              !trimmedLine.contains('首先') &&
              !trimmedLine.contains('步驟') &&
              !trimmedLine.contains('解') &&
              !trimmedLine.contains('化簡') &&
              !trimmedLine.contains('利用')) {
            debugPrint(
                "🔧 移除原始 LaTeX 標記行: ${trimmedLine.substring(0, math.min(50, trimmedLine.length))}...");
            continue;
          }
        }
      }

      // 標記已找到解法開始（包含解法相關關鍵詞）
      if (!foundSolutionStart &&
          (trimmedLine.contains('首先') ||
              trimmedLine.contains('理由') ||
              trimmedLine.contains('步驟') ||
              trimmedLine.contains('化簡') ||
              trimmedLine.contains('利用') ||
              (trimmedLine.contains('解') && !trimmedLine.contains('題目')))) {
        foundSolutionStart = true;
      }

      // 保留這行
      filteredLines.add(line);
    }

    cleanedContent = filteredLines.join('\n');

    // 移除多餘的換行（3個以上換成2個）
    cleanedContent = cleanedContent.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 移除開頭和結尾的空白行
    cleanedContent = cleanedContent.replaceAll(RegExp(r'^\n+|\n+$'), '');

    // 將內容按段落分割，每個段落單獨顯示
    final paragraphs = cleanedContent.split('\n\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((paragraph) {
        final trimmedParagraph = paragraph.trim();
        if (trimmedParagraph.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: LatexText(
            text: trimmedParagraph,
            fontSize: 15,
            lineHeight: 1.85,
            textColor: AppColors.textPrimary,
          ),
        );
      }).toList(),
    );
  }

  /// 題目資訊卡片（年級、章節、核心觀念）
  Widget _buildProblemInfoCard(SolverResult state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 簡化標籤顯示：只顯示科目和題型分類（可編輯）
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 科目（可編輯）- 橘色
              InkWell(
                onTap: () {
                  AppUX.feedbackClick();
                  _showSubjectDialog(context, ref);
                },
                borderRadius: BorderRadius.circular(8),
                child: _buildInfoChip(
                  icon: Icons.menu_book_outlined,
                  label: state.subject ?? '其他',
                  color: const Color(0xFFFF9800),
                ),
              ),
              // 題型分類（可編輯）- 藍色
              InkWell(
                onTap: () {
                  AppUX.feedbackClick();
                  _showCategoryDialog(context, ref);
                },
                borderRadius: BorderRadius.circular(8),
                child: _buildInfoChip(
                  icon: Icons.label_outline,
                  label: state.category ?? '其他',
                  color: const Color(0xFF2196F3),
                ),
              ),
            ],
          ),
          // 上方標籤和下方核心觀念之間增加間距
          const SizedBox(height: 16),

          // 核心觀念（過濾掉「AI 解析」）
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.keyConcepts
                        .where((concept) => concept != 'AI 解析')
                        .isNotEmpty) ...[
                      const Text(
                        "核心觀念",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: state.keyConcepts
                            .where((concept) => concept != 'AI 解析')
                            .map((concept) =>
                                _buildConceptTag(concept, onDelete: () {
                                  AppUX.feedbackClick();
                                  ref
                                      .read(solverNotifierProvider.notifier)
                                      .removeKeyConcept(concept);
                                  Future.delayed(
                                      const Duration(milliseconds: 300), () {
                                    _saveAllTagsToDatabase();
                                  });
                                }))
                            .toList(),
                      ),
                    ] else ...[
                      const Text(
                        "核心觀念",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              // 新增標籤按鈕
              InkWell(
                onTap: () {
                  AppUX.feedbackClick();
                  _showAddTagDialog(context, ref);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: const Color(0xFF1976D2), width: 1.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: Color(0xFF1976D2)),
                      SizedBox(width: 4),
                      Text(
                        "新增",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 資訊標籤（年級、章節）
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 核心觀念標籤
  Widget _buildConceptTag(String text, {VoidCallback? onDelete}) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 8, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE3F2FD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1976D2),
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(
                Icons.close,
                size: 14,
                color: Color(0xFF1976D2),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 顯示新增標籤對話框（單題目模式）
  void _showAddTagDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("新增標籤"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "輸入標籤名稱...",
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                ref
                    .read(solverNotifierProvider.notifier)
                    .addKeyConcept(value.trim());
                Navigator.of(dialogContext).pop();
                Future.delayed(const Duration(milliseconds: 300), () {
                  _saveAllTagsToDatabase();
                });
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("取消"),
            ),
            TextButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) {
                  ref
                      .read(solverNotifierProvider.notifier)
                      .addKeyConcept(value);
                  Navigator.of(dialogContext).pop();
                  Future.delayed(const Duration(milliseconds: 300), () {
                    _saveAllTagsToDatabase();
                  });
                }
              },
              child: const Text("確定"),
            ),
          ],
        );
      },
    );
  }

  /// 顯示新增標籤對話框（多題目模式）
  void _showAddTagDialogForMulti(BuildContext context, int problemIndex) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("新增標籤"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "輸入標籤名稱...",
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                final problem = widget.multipleProblems![problemIndex];
                final originalKeyConcepts =
                    (problem['keyConcepts'] as List<dynamic>?)
                            ?.map((c) => c.toString())
                            .toList() ??
                        [];
                final currentConcepts = List<String>.from(
                    _editedKeyConcepts[problemIndex] ?? originalKeyConcepts);
                if (!currentConcepts.contains(value.trim())) {
                  currentConcepts.add(value.trim());
                  setState(() {
                    _editedKeyConcepts[problemIndex] = currentConcepts;
                  });
                }
                Navigator.of(dialogContext).pop();
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("取消"),
            ),
            TextButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) {
                  final problem = widget.multipleProblems![problemIndex];
                  final originalKeyConcepts =
                      (problem['keyConcepts'] as List<dynamic>?)
                              ?.map((c) => c.toString())
                              .toList() ??
                          [];
                  final currentConcepts = List<String>.from(
                      _editedKeyConcepts[problemIndex] ?? originalKeyConcepts);
                  if (!currentConcepts.contains(value)) {
                    currentConcepts.add(value);
                    setState(() {
                      _editedKeyConcepts[problemIndex] = currentConcepts;
                    });
                  }
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text("確定"),
            ),
          ],
        );
      },
    );
  }

  /// 多題目模式：顯示科目選擇對話框
  void _showSubjectDialogForMulti(BuildContext context, int problemIndex) {
    if (widget.multipleProblems == null ||
        problemIndex >= widget.multipleProblems!.length) {
      return;
    }

    final problem = widget.multipleProblems![problemIndex];
    final currentSubject = _editedSubjects[problemIndex] ??
        (problem['subject']?.toString() ?? '其他');
    final currentCategory = _editedCategories[problemIndex] ??
        (problem['category']?.toString() ?? '其他');
    final subjects = ['數學', '英文', '國文', '自然', '地理', '歷史', '公民', '其他'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("選擇科目"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                final subject = subjects[index];
                final isSelected = subject == currentSubject;
                return ListTile(
                  title: Text(subject),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Color(0xFF2196F3))
                      : null,
                  selected: isSelected,
                  onTap: () {
                    final newCategories = _getCategoriesBySubject(subject);
                    setState(() {
                      _editedSubjects[problemIndex] = subject;
                      if (!newCategories.contains(currentCategory)) {
                        _editedCategories[problemIndex] = '其他';
                      }
                    });
                    Navigator.of(dialogContext).pop();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("取消"),
            ),
          ],
        );
      },
    );
  }

  /// 多題目模式：顯示分類選擇對話框
  void _showCategoryDialogForMulti(BuildContext context, int problemIndex) {
    if (widget.multipleProblems == null ||
        problemIndex >= widget.multipleProblems!.length) {
      return;
    }

    final problem = widget.multipleProblems![problemIndex];
    final currentSubject = _editedSubjects[problemIndex] ??
        (problem['subject']?.toString() ?? '其他');
    final currentCategory = _editedCategories[problemIndex] ??
        (problem['category']?.toString() ?? '其他');
    final categories = _getCategoriesBySubject(currentSubject);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("選擇題型分類（$currentSubject）"),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = category == currentCategory;
                return ListTile(
                  title: Text(category),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Color(0xFF2196F3))
                      : null,
                  selected: isSelected,
                  onTap: () {
                    setState(() {
                      _editedCategories[problemIndex] = category;
                    });
                    Navigator.of(dialogContext).pop();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("取消"),
            ),
          ],
        );
      },
    );
  }

  /// 顯示科目選擇對話框
  void _showSubjectDialog(BuildContext context, WidgetRef ref) {
    final currentSubject = ref.read(solverNotifierProvider).subject ?? '其他';

    final subjects = ['數學', '英文', '國文', '自然', '地理', '歷史', '公民', '其他'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("選擇科目"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                final subject = subjects[index];
                final isSelected = subject == currentSubject;
                return ListTile(
                  title: Text(subject),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Color(0xFF2196F3))
                      : null,
                  selected: isSelected,
                  onTap: () {
                    AppUX.feedbackClick();
                    final solverNotifier =
                        ref.read(solverNotifierProvider.notifier);
                    final currentCategory =
                        ref.read(solverNotifierProvider).category ?? '其他';

                    // 更新 subject
                    solverNotifier.updateSubject(subject);

                    // 檢查當前 category 是否在新 subject 的分類列表中
                    final newCategories = _getCategoriesBySubject(subject);
                    if (!newCategories.contains(currentCategory)) {
                      // 如果當前 category 不在新 subject 的分類列表中，重置為「其他」
                      solverNotifier.updateCategory('其他');
                    }

                    Navigator.of(dialogContext).pop();

                    // 立即保存到資料庫（移除延遲）
                    _handleSubjectOrCategoryChange(immediate: true);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("取消"),
            ),
          ],
        );
      },
    );
  }

  /// 根據科目獲取對應的題型分類列表（與 Gemini prompt 一致）
  List<String> _getCategoriesBySubject(String subject) {
    switch (subject) {
      case '數學':
        return [
          '數與式',
          '一元一次方程式',
          '二元一次方程式',
          '一元二次方程式',
          '函數與圖形',
          '比例與百分比',
          '指數與對數',
          '數列',
          '平面幾何',
          '立體幾何',
          '三角形',
          '相似與全等',
          '三角函數',
          '向量',
          '機率',
          '統計',
          '不等式',
          '其他',
        ];
      case '國文':
        return [
          '字音字形',
          '語詞應用',
          '成語運用',
          '修辭判斷',
          '文法句型',
          '文意理解',
          '文言文閱讀',
          '白話文閱讀',
          '詩詞賞析',
          '其他',
        ];
      case '英文':
        return [
          '單字',
          '文法',
          '句型結構',
          '閱讀理解',
          '克漏字',
          '文意選填',
          '其他',
        ];
      case '自然':
        return [
          '物理-力學',
          '物理-熱學',
          '物理-光學',
          '物理-電磁學',
          '化學-物質結構',
          '化學-化學反應',
          '化學-酸鹼鹽',
          '生物-細胞與遺傳',
          '生物-生物多樣性',
          '地科-地球科學',
          '其他',
        ];
      case '地理':
        return [
          '台灣地理',
          '世界地理',
          '地圖判讀',
          '地形與氣候',
          '人口與資源',
          '經濟活動',
          '區域發展',
          '其他',
        ];
      case '歷史':
        return [
          '台灣史',
          '中國史',
          '世界史',
          '古代史',
          '近代史',
          '現代史',
          '其他',
        ];
      case '公民':
        return [
          '法律與政治',
          '經濟',
          '社會制度',
          '權利義務',
          '民主與人權',
          '政府與憲法',
          '其他',
        ];
      default:
        return ['其他'];
    }
  }

  /// 顯示分類選擇對話框（根據 Gemini prompt 中的分類清單）
  void _showCategoryDialog(BuildContext context, WidgetRef ref) {
    final solverState = ref.read(solverNotifierProvider);
    final currentCategory = solverState.category ?? '其他';
    final currentSubject = solverState.subject ?? '其他';

    // 根據科目動態獲取題型分類列表
    final categories = _getCategoriesBySubject(currentSubject);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("選擇題型分類（$currentSubject）"),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = category == currentCategory;
                return ListTile(
                  title: Text(category),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Color(0xFF2196F3))
                      : null,
                  selected: isSelected,
                  onTap: () {
                    AppUX.feedbackClick();
                    ref
                        .read(solverNotifierProvider.notifier)
                        .updateCategory(category);
                    Navigator.of(dialogContext).pop();
                    // 更新資料庫
                    _handleSubjectOrCategoryChange();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("取消"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60), // 增加頂部間距，讓卡片往下移
          // 1. 歡迎卡片
          _buildWelcomeCard(),

          const SizedBox(height: 24),

          // 2. 快速操作區
          _buildQuickActions(),

          const SizedBox(height: 24),

          // 3. 使用教學
          _buildHowToUse(),

          const SizedBox(height: 24),

          // 4. 學習小提示
          _buildStudyTips(),

          const SizedBox(height: 100), // 底部留白
        ],
      ),
    );
  }

  /// 歡迎卡片
  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.textPrimary,
            AppColors.textPrimary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "錯題解析高手",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "AI 智能解題，一鍵拍照即可獲得完整解析\n幫孩子理解每個步驟，建立正確觀念",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: Colors.amber, size: 18),
                SizedBox(width: 8),
                Text(
                  "完整步驟解析 + 核心觀念整理",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 快速操作區
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "快速開始",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.camera_alt,
                title: "拍照解題",
                subtitle: "拍攝考卷上的題目",
                color: const Color(0xFF007AFF),
                onTap: () async {
                  if (!await PaywallGate.guardFeatureAccess(
                    context,
                    ref,
                    TrialFeature.cameraSolve,
                  )) {
                    return;
                  }
                  if (!mounted) return;
                  AppUX.feedbackClick();
                  final image = await ImageService().pickAndCompressImage(
                    context,
                    fromCamera: true,
                  );
                  if (image != null && mounted) {
                    Navigator.of(context).push(
                      AppUX.fadeRoute(MultiCropScreen(imageFile: image)),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.photo_library,
                title: "相簿選取",
                subtitle: "從相簿選擇題目",
                color: const Color(0xFF34C759),
                onTap: () async {
                  if (!await PaywallGate.guardFeatureAccess(
                    context,
                    ref,
                    TrialFeature.cameraSolve,
                  )) {
                    return;
                  }
                  if (!mounted) return;
                  AppUX.feedbackClick();
                  final image = await ImageService().pickAndCompressImage(
                    context,
                    fromCamera: false,
                  );
                  if (image != null && mounted) {
                    Navigator.of(context).push(
                      AppUX.fadeRoute(MultiCropScreen(imageFile: image)),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 使用教學
  Widget _buildHowToUse() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "如何使用",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildStepItem(
                step: "1",
                title: "拍攝題目",
                description: "對準考卷或練習本上的題目拍照",
                icon: Icons.camera_alt_outlined,
              ),
              const Divider(height: 24),
              _buildStepItem(
                step: "2",
                title: "框選題目",
                description: "用手指框選要解析的題目區域",
                icon: Icons.crop_outlined,
              ),
              const Divider(height: 24),
              _buildStepItem(
                step: "3",
                title: "AI 解析",
                description: "系統自動辨識並生成詳細解答",
                icon: Icons.psychology_outlined,
              ),
              const Divider(height: 24),
              _buildStepItem(
                step: "4",
                title: "收藏複習",
                description: "將錯題加入題庫，隨時複習",
                icon: Icons.bookmark_outline,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required String step,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 學習小提示
  Widget _buildStudyTips() {
    final tips = [
      "💡 每天複習 3-5 題錯題，效果最佳",
      "📚 理解解題思路比死記硬背更重要",
      "🎯 專注於常錯的題型，逐個突破",
      "⏰ 考前一週是複習錯題的黃金時間",
    ];

    // 每天顯示不同的提示
    final tipIndex = DateTime.now().day % tips.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        children: [
          const Icon(Icons.tips_and_updates,
              color: Color(0xFFFFB300), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "學習小提示",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tips[tipIndex],
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 100, height: 16, color: Colors.grey[200]),
        const SizedBox(height: 8),
        Container(width: double.infinity, height: 16, color: Colors.grey[200]),
        const SizedBox(height: 8),
        Text(message, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildSolutionSkeleton() {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
      ),
    );
  }

  Widget _buildThinkingSkeleton() {
    return Column(
      children: [
        _buildSkeletonCard(),
        const SizedBox(height: 16),
        _buildSkeletonCard(),
        const SizedBox(height: 16),
        _buildSkeletonCard(),
      ],
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 80, height: 20, color: Colors.grey[100]),
          const SizedBox(height: 16),
          Container(
              width: double.infinity, height: 14, color: Colors.grey[100]),
          const SizedBox(height: 10),
          Container(width: 200, height: 14, color: Colors.grey[100]),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// 解法區標題和加入錯題本按鈕（同一行）
  Widget _buildSolutionHeader(SolverResult state) {
    // 如果從錯題本進入，不顯示「加入錯題本」按鈕
    if (widget.isFromMistakes) {
      return const Text(
        "解題詳情",
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      );
    }

    // 空狀態時不顯示按鈕
    final hasContent =
        widget.originalImage != null || widget.initialLatex != null;
    // 只有在完成狀態時才顯示加入錯題本按鈕
    final canSave = hasContent && state.status == SolverStatus.completed;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          "AI 深度解析",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (canSave)
          TextButton.icon(
            onPressed: _toggleSave,
            icon: Icon(
              _isSaved ? Icons.check_circle : Icons.bookmark_border,
              size: 18,
              color: _isSaved ? AppColors.textSecondary : AppColors.textPrimary,
            ),
            label: Text(
              _isSaved ? "已加入" : "加入錯題本",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    _isSaved ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  Widget? _buildFab(SolverResult state) {
    // FAB 已移除，功能移到標題旁
    return null;
  }
}
