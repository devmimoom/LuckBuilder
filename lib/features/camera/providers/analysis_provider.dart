import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import '../../../core/services/gemini_service.dart' hide debugPrint;
import '../utils/crop_image_helper.dart';

part 'analysis_provider.g.dart';

const bool _enableVerboseAnalysisLogs =
    bool.fromEnvironment('LB_VERBOSE_ANALYSIS_LOGS', defaultValue: false);

void debugPrint(String? message, {int? wrapWidth}) {
  if (!foundation.kDebugMode || !_enableVerboseAnalysisLogs) return;
  foundation.debugPrint(message, wrapWidth: wrapWidth);
}

enum AnalysisStatus { waiting, processing, completed, failed }

class AnalysisTask {
  final String id;
  final AnalysisStatus status;
  final String? title;
  final double progress;
  final String? imagePath; // 原始圖片路徑
  final String? cropPath; // 裁切後的圖片路徑
  final String? resultLatex; // OCR 辨識結果（題目文字）

  // Gemini 解析結果
  final String? subject; // 科目（國、英、數、自然、地理、歷史、公民、其他）
  final String? gradeLevel; // 年級
  final String? category; // 分類（一般、幾何、代數、文法、閱讀等）
  final String? chapter; // 章節
  final List<String> keyConcepts; // 核心觀念
  final List<Map<String, String>>
      solutions; // 解法列表 [{title: "標題", content: "內容"}]

  // 重試所需的信息
  final Rect? cropRect; // 裁切區域（用於重試）
  final Size? displaySize; // 顯示大小（用於重試）

  AnalysisTask({
    required this.id,
    this.status = AnalysisStatus.waiting,
    this.title,
    this.progress = 0.0,
    this.imagePath,
    this.cropPath,
    this.resultLatex,
    this.subject,
    this.gradeLevel,
    this.category,
    this.chapter,
    this.keyConcepts = const [],
    this.solutions = const [],
    this.cropRect,
    this.displaySize,
  });

  AnalysisTask copyWith({
    AnalysisStatus? status,
    String? title,
    double? progress,
    String? imagePath,
    String? cropPath,
    String? resultLatex,
    String? subject,
    String? gradeLevel,
    String? category,
    String? chapter,
    List<String>? keyConcepts,
    List<Map<String, String>>? solutions,
    Rect? cropRect,
    Size? displaySize,
  }) {
    return AnalysisTask(
      id: id,
      status: status ?? this.status,
      title: title ?? this.title,
      progress: progress ?? this.progress,
      imagePath: imagePath ?? this.imagePath,
      cropPath: cropPath ?? this.cropPath,
      resultLatex: resultLatex ?? this.resultLatex,
      subject: subject ?? this.subject,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      category: category ?? this.category,
      chapter: chapter ?? this.chapter,
      keyConcepts: keyConcepts ?? this.keyConcepts,
      solutions: solutions ?? this.solutions,
      cropRect: cropRect ?? this.cropRect,
      displaySize: displaySize ?? this.displaySize,
    );
  }
}

@Riverpod(keepAlive: true)
class AnalysisQueue extends _$AnalysisQueue {
  @override
  List<AnalysisTask> build() => [];

  /// 開始分析流程
  /// [imagePath] 原始圖片路徑
  /// [rects] 在螢幕上框選的區域
  /// [displaySize] 圖片在螢幕上顯示的大小 (用於座標轉換)
  /// [erasePaths] 筆刷塗掉的路徑（屏幕座標），將應用為實際遮罩
  Future<void> startAnalysis({
    required String imagePath,
    required List<Rect> rects,
    required Size displaySize,
    List<Path> erasePaths = const [],
  }) async {
    debugPrint("=== [AnalysisQueue] startAnalysis 被調用 ===");
    debugPrint("imagePath: $imagePath");
    debugPrint("rects 數量: ${rects.length}");
    debugPrint("displaySize: $displaySize");
    debugPrint("erasePaths 數量: ${erasePaths.length}");

    // 1. 初始化任務列表（保存裁切區域和顯示大小，用於重試）
    state = List.generate(
      rects.length,
      (index) => AnalysisTask(
        id: 'task_${DateTime.now().millisecondsSinceEpoch}_$index',
        imagePath: imagePath,
        cropRect: rects[index],
        displaySize: displaySize,
      ),
    );

    debugPrint("已初始化 ${state.length} 個任務");

    // 2. 開始處理隊列（不 await，讓它在後台運行）
    // 注意：這裡不 await 是為了讓頁面可以立即跳轉，狀態更新會自動觸發 UI 刷新
    _processQueue(imagePath, rects, displaySize, erasePaths)
        .catchError((error) {
      debugPrint("❌ _processQueue 發生錯誤: $error");
    });
  }

  Future<void> _processQueue(String imagePath, List<Rect> rects,
      Size displaySize, List<Path> erasePaths) async {
    debugPrint("=== [AnalysisQueue] _processQueue 開始 ===");
    CropImageResult cropResult;
    try {
      cropResult = await CropImageHelper.cropSelectedRegions(
        imagePath: imagePath,
        rects: rects,
        displaySize: displaySize,
        erasePaths: erasePaths,
      );
    } catch (e) {
      debugPrint("❌ 裁切失敗: $e");
      for (var i = 0; i < rects.length; i++) {
        _updateTask(i, status: AnalysisStatus.failed, title: '裁切圖片失敗');
      }
      return;
    }

    for (int i = 0; i < rects.length; i++) {
      debugPrint("=== 處理任務 $i ===");
      _updateTask(i,
          status: AnalysisStatus.processing, title: '正在裁切與辨識題目 ${i + 1}...');

      try {
        final cropPath = cropResult.cropPaths[i];
        debugPrint("裁切圖片已儲存: $cropPath");

        _updateTask(i,
            progress: 0.3, cropPath: cropPath, title: '正在 Gemini OCR 辨識題目...');

        // 3. 使用 Gemini 進行 OCR（替代 Mathpix）
        debugPrint("=== 呼叫 GeminiService OCR ===");
        final latex = await GeminiService().recognizeImage(File(cropPath));
        debugPrint("Gemini OCR 結果: $latex");

        if (latex == null || latex.isEmpty) {
          _updateTask(i, status: AnalysisStatus.failed, title: 'OCR 辨識失敗');
          debugPrint("任務 $i OCR 辨識失敗（API 返回 null）");
          continue; // 跳過這個任務，繼續下一個
        }

        // OCR 成功，更新進度
        _updateTask(
          i,
          progress: 0.6,
          resultLatex: latex,
          title: 'OCR 完成，正在 AI 解析...',
        );

        // 4. 自動呼叫 Gemini API 進行解析（包含題目、答案、分類）
        debugPrint("=== 呼叫 GeminiService 進行解析 ===");
        _updateTask(i, progress: 0.7, title: 'AI 正在分析題目與生成解答...');

        // 傳遞裁剪後的圖片給 Gemini，讓它能夠看到圖表、幾何圖形等視覺資訊
        final croppedImageFile = File(cropPath);
        final geminiResult = await GeminiService().solveProblem(
          latex,
          imageFile: croppedImageFile,
        );

        if (geminiResult != null) {
          // 解析 Gemini 返回的 JSON
          final solutions = <Map<String, String>>[];
          final rawSolutions =
              geminiResult['solutions'] as List<dynamic>? ?? [];
          for (final item in rawSolutions) {
            if (item is Map<String, dynamic>) {
              solutions.add({
                'title': item['title']?.toString() ?? '解法',
                'content': item['content']?.toString() ?? '',
              });
            }
          }

          final keyConcepts = <String>[];
          final rawConcepts =
              geminiResult['key_concepts'] as List<dynamic>? ?? [];
          for (final concept in rawConcepts) {
            keyConcepts.add(concept.toString());
          }

          // 更新任務為完成狀態，包含所有解析結果
          _updateTask(
            i,
            status: AnalysisStatus.completed,
            progress: 1.0,
            resultLatex: latex, // OCR 辨識的題目文字
            subject: geminiResult['subject']?.toString() ?? '其他',
            gradeLevel: geminiResult['grade_level']?.toString(),
            category: geminiResult['category']?.toString() ?? '一般',
            chapter: geminiResult['chapter']?.toString(),
            keyConcepts: keyConcepts,
            solutions: solutions,
            title: '解析完成！',
          );
          debugPrint("任務 $i 完成（OCR + Gemini 解析）");
        } else {
          // Gemini 失敗，但 OCR 成功，仍然標記為完成（至少顯示 OCR 結果）
          debugPrint("任務 $i Gemini 解析失敗，但 OCR 成功");
          _updateTask(
            i,
            status: AnalysisStatus.completed,
            progress: 1.0,
            resultLatex: latex,
            title: 'OCR 完成（AI 解析失敗）',
          );
        }
      } catch (e, stack) {
        debugPrint("任務 $i 發生錯誤: $e");
        debugPrint("Stack trace: $stack");
        _updateTask(i, status: AnalysisStatus.failed, title: '處理發生錯誤');
      }
    }

    debugPrint("=== [AnalysisQueue] _processQueue 結束 ===");
  }

  /// 重試特定任務
  Future<void> retryTask(int taskIndex) async {
    if (taskIndex < 0 || taskIndex >= state.length) {
      debugPrint("❌ 重試失敗: 任務索引 $taskIndex 超出範圍");
      return;
    }

    final task = state[taskIndex];
    if (task.imagePath == null) {
      debugPrint("❌ 重試失敗: 任務沒有圖片路徑");
      return;
    }

    if (task.cropRect == null || task.displaySize == null) {
      debugPrint("❌ 重試失敗: 任務沒有裁切區域或顯示大小信息");
      return;
    }

    debugPrint("🔄 開始重試任務 $taskIndex");

    // 重置任務狀態
    _updateTask(
      taskIndex,
      status: AnalysisStatus.processing,
      progress: 0.0,
      title: '正在重試 OCR 辨識...',
      resultLatex: null,
      gradeLevel: null,
      chapter: null,
      keyConcepts: [],
      solutions: [],
    );

    // 重新處理單個任務
    await _processSingleTask(
      taskIndex,
      task.imagePath!,
      task.cropRect!,
      task.displaySize!,
    );
  }

  /// 處理單個任務（用於重試）
  Future<void> _processSingleTask(
    int taskIndex,
    String imagePath,
    Rect rect,
    Size displaySize,
  ) async {
    try {
      _updateTask(taskIndex,
          status: AnalysisStatus.processing, title: '正在裁切題目...');
      final cropResult = await CropImageHelper.cropSelectedRegions(
        imagePath: imagePath,
        rects: [rect],
        displaySize: displaySize,
      );
      final cropPath = cropResult.firstCropPath;
      if (cropPath == null) {
        _updateTask(taskIndex, status: AnalysisStatus.failed, title: '裁切圖片失敗');
        return;
      }

      _updateTask(taskIndex,
          progress: 0.3, cropPath: cropPath, title: '正在 Gemini OCR 辨識題目...');

      // 使用 Gemini 進行 OCR
      final latex = await GeminiService().recognizeImage(File(cropPath));

      if (latex == null || latex.isEmpty) {
        _updateTask(taskIndex,
            status: AnalysisStatus.failed, title: 'OCR 辨識失敗');
        return;
      }

      // OCR 成功
      _updateTask(
        taskIndex,
        progress: 0.6,
        resultLatex: latex,
        title: 'OCR 完成，正在 AI 解析...',
      );

      // Gemini 解析
      _updateTask(taskIndex, progress: 0.7, title: 'AI 正在分析題目與生成解答...');

      // 傳遞裁剪後的圖片給 Gemini，讓它能夠看到圖表、幾何圖形等視覺資訊
      final croppedImageFile = File(cropPath);
      final geminiResult = await GeminiService().solveProblem(
        latex,
        imageFile: croppedImageFile,
      );

      if (geminiResult != null) {
        final solutions = <Map<String, String>>[];
        final rawSolutions = geminiResult['solutions'] as List<dynamic>? ?? [];
        for (final item in rawSolutions) {
          if (item is Map<String, dynamic>) {
            solutions.add({
              'title': item['title']?.toString() ?? '解法',
              'content': item['content']?.toString() ?? '',
            });
          }
        }

        final keyConcepts = <String>[];
        final rawConcepts =
            geminiResult['key_concepts'] as List<dynamic>? ?? [];
        for (final concept in rawConcepts) {
          keyConcepts.add(concept.toString());
        }

        _updateTask(
          taskIndex,
          status: AnalysisStatus.completed,
          progress: 1.0,
          resultLatex: latex,
          subject: geminiResult['subject']?.toString() ?? '其他',
          gradeLevel: geminiResult['grade_level']?.toString(),
          chapter: geminiResult['chapter']?.toString(),
          keyConcepts: keyConcepts,
          solutions: solutions,
          title: '解析完成！',
        );
      } else {
        // Gemini 失敗，但 OCR 成功
        _updateTask(
          taskIndex,
          status: AnalysisStatus.completed,
          progress: 1.0,
          resultLatex: latex,
          title: 'OCR 完成（AI 解析失敗）',
        );
      }
    } catch (e, stack) {
      debugPrint("任務 $taskIndex 重試時發生錯誤: $e");
      debugPrint("Stack trace: $stack");
      _updateTask(taskIndex, status: AnalysisStatus.failed, title: '重試失敗');
    }
  }

  void _updateTask(
    int index, {
    AnalysisStatus? status,
    String? title,
    double? progress,
    String? cropPath,
    String? resultLatex,
    String? subject,
    String? gradeLevel,
    String? category,
    String? chapter,
    List<String>? keyConcepts,
    List<Map<String, String>>? solutions,
  }) {
    if (index < 0 || index >= state.length) {
      debugPrint("⚠️ _updateTask 錯誤: index $index 超出範圍 (總數: ${state.length})");
      return;
    }

    // 創建新的 list 以確保 Riverpod 檢測到變化
    final newTasks = List<AnalysisTask>.from(state);
    newTasks[index] = state[index].copyWith(
      status: status,
      title: title,
      progress: progress,
      cropPath: cropPath,
      resultLatex: resultLatex,
      subject: subject,
      gradeLevel: gradeLevel,
      category: category,
      chapter: chapter,
      keyConcepts: keyConcepts,
      solutions: solutions,
    );

    state = newTasks;

    debugPrint("✅ 任務 $index 狀態已更新: ${status ?? state[index].status}");
  }
}
