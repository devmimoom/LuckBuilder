import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' as foundation;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/services/gemini_service.dart' hide debugPrint;
import '../../../core/services/math_ocr_service.dart';

part 'solver_provider.g.dart';

const bool _enableVerboseSolverLogs =
    bool.fromEnvironment('LB_VERBOSE_SOLVER_LOGS', defaultValue: false);

void debugPrint(String? message, {int? wrapWidth}) {
  if (!foundation.kDebugMode || !_enableVerboseSolverLogs) return;
  foundation.debugPrint(message, wrapWidth: wrapWidth);
}

/// 解題流程的狀態
enum SolverStatus {
  idle, // 等待開始
  ocr, // 正在 OCR 辨識
  thinking, // 正在 AI 思考
  completed, // 完成
  failed, // 失敗
}

/// 解題結果資料模型
class SolverResult {
  final SolverStatus status;
  final String? recognizedLatex; // OCR 辨識的原始文字
  final String? subject; // 科目（國、英、數、自然、地理、歷史、公民、其他）
  final String? gradeLevel; // 年級
  final String? category; // 分類（一般、幾何、代數、文法、閱讀等）
  final String? chapter; // 章節
  final List<String> keyConcepts; // 核心觀念
  final List<SolutionItem> solutions; // 解法列表
  final String? errorMessage; // 錯誤訊息

  const SolverResult({
    this.status = SolverStatus.idle,
    this.recognizedLatex,
    this.subject,
    this.gradeLevel,
    this.category,
    this.chapter,
    this.keyConcepts = const [],
    this.solutions = const [],
    this.errorMessage,
  });

  SolverResult copyWith({
    SolverStatus? status,
    String? recognizedLatex,
    String? subject,
    String? gradeLevel,
    String? category,
    String? chapter,
    List<String>? keyConcepts,
    List<SolutionItem>? solutions,
    String? errorMessage,
  }) {
    return SolverResult(
      status: status ?? this.status,
      recognizedLatex: recognizedLatex ?? this.recognizedLatex,
      subject: subject ?? this.subject,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      category: category ?? this.category,
      chapter: chapter ?? this.chapter,
      keyConcepts: keyConcepts ?? this.keyConcepts,
      solutions: solutions ?? this.solutions,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 單一解法項目
class SolutionItem {
  final String title;
  final String content;

  const SolutionItem({required this.title, required this.content});
}

/// Riverpod AsyncNotifier：管理「OCR → Gemini → 結果」的完整流程
@riverpod
class SolverNotifier extends _$SolverNotifier {
  @override
  SolverResult build() => const SolverResult();

  /// 開始完整的解題流程
  /// [imageFile] 要分析的圖片檔案
  /// [initialLatex] 如果已經有有效的辨識結果，可以直接傳入（跳過 OCR）
  /// [forceRestart] 是否強制重新開始（即使狀態不是 idle）
  Future<void> startAnalysis({
    File? imageFile,
    String? initialLatex,
    bool forceRestart = false,
  }) async {
    debugPrint("🔄 SolverNotifier.startAnalysis 被呼叫");
    debugPrint("  當前狀態: ${state.status}");
    debugPrint(
        "  initialLatex: ${initialLatex != null ? '已提供 (${initialLatex.length} 字元)' : 'null'}");
    debugPrint("  imageFile: ${imageFile != null ? '已提供' : 'null'}");
    debugPrint("  forceRestart: $forceRestart");

    // 🛡️ 防重複呼叫檢查（但允許在 completed/failed 狀態下重新開始）
    if (!forceRestart &&
        state.status != SolverStatus.idle &&
        state.status != SolverStatus.completed &&
        state.status != SolverStatus.failed) {
      debugPrint("⚠️ 分析已在進行中 (${state.status})，忽略重複呼叫");
      debugPrint("   提示: 如果狀態卡住，請使用 forceRestart=true 強制重新開始");
      return;
    }

    // 如果狀態是 completed 或 failed，先重置為 idle
    if (state.status == SolverStatus.completed ||
        state.status == SolverStatus.failed) {
      debugPrint("🔄 檢測到已完成或失敗狀態，重置為 idle");
      state = state.copyWith(status: SolverStatus.idle);
    }

    // 檢查 initialLatex 是否有效（非空且有內容）
    final hasValidLatex = initialLatex != null &&
        initialLatex.trim().isNotEmpty &&
        initialLatex != 'null'; // 避免字串 "null"

    // 如果已經有有效的 LaTeX，直接跳到 Gemini 思考（OCR 已完成）
    if (hasValidLatex) {
      debugPrint("✅ 使用已有的有效 OCR 結果，跳過重複辨識");
      state = state.copyWith(
        status: SolverStatus.thinking,
        recognizedLatex: initialLatex,
      );
      // 即使已有 OCR 結果，如果有圖片也傳遞給 Gemini（用於理解圖表）
      await _askGemini(initialLatex, imageFile: imageFile);
      return;
    }

    debugPrint("⚠️ OCR 結果無效或不存在，需要重新辨識");

    // 需要先做 OCR
    if (imageFile == null) {
      debugPrint("❌ 錯誤：未提供圖片檔案，且沒有有效的 OCR 結果");
      state = state.copyWith(
        status: SolverStatus.failed,
        errorMessage: "未提供圖片，且沒有有效的辨識結果",
      );
      return;
    }

    // 步驟 1：使用可切換的數學 OCR 服務
    debugPrint("📷 開始數學 OCR 辨識...");
    state = state.copyWith(status: SolverStatus.ocr);

    final latex = await MathOcrService().recognizeImage(imageFile);

    if (latex == null || latex.isEmpty) {
      debugPrint("❌ 數學 OCR 失敗");
      state = state.copyWith(
        status: SolverStatus.failed,
        errorMessage: "文字辨識失敗，請確認圖片清晰",
      );
      return;
    }

    debugPrint(
        "✅ 數學 OCR 完成: ${latex.substring(0, math.min(50, latex.length))}...");
    state = state.copyWith(
      status: SolverStatus.thinking,
      recognizedLatex: latex,
    );

    // 步驟 2：Gemini 思考解法（傳遞圖片以幫助理解圖表）
    await _askGemini(latex, imageFile: imageFile);
  }

  /// 呼叫 Gemini API 進行解題
  /// [questionText] OCR 辨識的題目文字
  /// [imageFile] 可選的圖片檔案，用於多模態輸入（幫助理解圖表、幾何圖形等）
  Future<void> _askGemini(String questionText, {File? imageFile}) async {
    debugPrint("🧠 呼叫 Gemini 解題...");
    debugPrint("   題目長度: ${questionText.length} 字元");
    debugPrint("   圖片: ${imageFile != null ? '已提供 (${imageFile.path})' : '無'}");

    final response = await GeminiService().solveProblem(
      questionText,
      imageFile: imageFile,
    );

    if (response == null) {
      // Gemini 失敗，但 OCR 成功，仍然顯示辨識結果
      debugPrint("❌ Gemini API 調用失敗");

      // 檢查 GeminiService 是否已初始化
      final geminiService = GeminiService();
      final isReady = geminiService.isReady;
      debugPrint("   GeminiService.isReady: $isReady");

      String errorMessage = "AI 解題服務暫時無法使用";
      if (!isReady) {
        errorMessage =
            "AI 解題服務未初始化，請確認 GEMINI_API_KEY 已正確設定。當前使用 gemini-pro 模型，如果失敗會嘗試 gemini-1.5-flash";
      }

      state = state.copyWith(
        status: SolverStatus.completed,
        solutions: [
          SolutionItem(
            title: "辨識結果",
            content: state.recognizedLatex ?? questionText,
          ),
          SolutionItem(
            title: "提示",
            content: "$errorMessage。請檢查 .env 檔案中的 GEMINI_API_KEY 設定。",
          ),
        ],
      );
      return;
    }

    debugPrint("✅ Gemini 回應成功");

    // 解析 Gemini 回傳的 JSON
    try {
      debugPrint("📦 開始解析 Gemini 回應...");
      debugPrint("   response keys: ${response.keys.toList()}");

      // 🔍 添加：詳細檢查 subject 字段
      if (response.containsKey('subject')) {
        final rawSubject = response['subject'];
        debugPrint(
            "   🔍 response['subject'] 原始值: $rawSubject (類型: ${rawSubject.runtimeType})");

        final subjectString = rawSubject?.toString();
        debugPrint("   🔍 轉換為字符串後: \"$subjectString\"");
      } else {
        debugPrint("   ⚠️ 警告：response 中沒有 'subject' 鍵！");
      }

      final solutions = <SolutionItem>[];
      final rawSolutions = response['solutions'] as List<dynamic>? ?? [];
      debugPrint("   solutions 數量: ${rawSolutions.length}");

      for (final item in rawSolutions) {
        if (item is Map<String, dynamic>) {
          final title = item['title']?.toString() ?? '解法';
          final content = item['content']?.toString() ?? '';
          debugPrint("   - 解法: $title (內容長度: ${content.length})");
          solutions.add(SolutionItem(
            title: title,
            content: content,
          ));
        }
      }

      final keyConcepts = <String>[];
      final rawConcepts = response['key_concepts'] as List<dynamic>? ?? [];
      for (final concept in rawConcepts) {
        keyConcepts.add(concept.toString());
      }

      final subject = response['subject']?.toString() ?? '其他';
      final gradeLevel = response['grade_level']?.toString();
      final category = response['category']?.toString() ?? '一般';
      final chapter = response['chapter']?.toString();

      // 🔍 添加：詳細檢查最終 subject 值
      debugPrint("   🔍 最終 subject 值: \"$subject\"");
      if (subject == '其他') {
        debugPrint("   ⚠️ 警告：subject 被設置為默認值 '其他'！");
        final rawSubject = response['subject'];
        if (rawSubject == null) {
          debugPrint("     原因：response['subject'] 為 null");
        } else {
          final subjectString = rawSubject.toString();
          if (subjectString.isEmpty) {
            debugPrint("     原因：toString() 返回空字符串");
          } else {
            debugPrint(
                "     原因：toString() 返回 \"$subjectString\"，但被 ?? 運算符覆蓋為 '其他'");
          }
        }
      }

      debugPrint("   subject: $subject");
      debugPrint("   gradeLevel: $gradeLevel");
      debugPrint("   category: $category");
      debugPrint("   chapter: $chapter");
      debugPrint("   keyConcepts: $keyConcepts");
      debugPrint("   solutions count: ${solutions.length}");

      state = state.copyWith(
        status: SolverStatus.completed,
        subject: subject,
        gradeLevel: gradeLevel,
        category: category,
        chapter: chapter,
        keyConcepts: keyConcepts,
        solutions: solutions,
      );

      debugPrint("✅ 狀態更新完成");
    } catch (e) {
      debugPrint("❌ 解析 Gemini 回應失敗: $e");
      state = state.copyWith(
        status: SolverStatus.completed,
        solutions: [
          SolutionItem(
            title: "辨識結果",
            content: state.recognizedLatex ?? questionText,
          ),
        ],
      );
    }
  }

  /// 設置預解析的結果（當從 AnalysisTask 傳入已解析的結果時使用）
  void setPreParsedResult({
    String? recognizedLatex,
    String? subject,
    String? gradeLevel,
    String? category,
    String? chapter,
    List<String> keyConcepts = const [],
    List<SolutionItem> solutions = const [],
  }) {
    state = SolverResult(
      status: SolverStatus.completed,
      recognizedLatex: recognizedLatex,
      subject: subject ?? '其他',
      gradeLevel: gradeLevel,
      category: category ?? '一般',
      chapter: chapter,
      keyConcepts: keyConcepts,
      solutions: solutions,
    );
  }

  /// 重置狀態
  void reset() {
    state = const SolverResult();
  }

  /// 更新核心觀念標籤
  void updateKeyConcepts(List<String> keyConcepts) {
    state = state.copyWith(keyConcepts: keyConcepts);
  }

  /// 更新 OCR 題目文字
  void updateRecognizedLatex(String recognizedLatex) {
    state = state.copyWith(recognizedLatex: recognizedLatex);
  }

  /// 添加核心觀念標籤
  void addKeyConcept(String concept) {
    final currentConcepts = List<String>.from(state.keyConcepts);
    if (!currentConcepts.contains(concept) && concept.trim().isNotEmpty) {
      currentConcepts.add(concept.trim());
      state = state.copyWith(keyConcepts: currentConcepts);
    }
  }

  /// 刪除核心觀念標籤
  void removeKeyConcept(String concept) {
    final currentConcepts = List<String>.from(state.keyConcepts);
    currentConcepts.remove(concept);
    state = state.copyWith(keyConcepts: currentConcepts);
  }

  /// 更新科目
  void updateSubject(String subject) {
    state = state.copyWith(subject: subject);
  }

  /// 更新年級
  void updateGradeLevel(String gradeLevel) {
    state = state.copyWith(gradeLevel: gradeLevel);
  }

  /// 更新分類
  void updateCategory(String category) {
    state = state.copyWith(category: category);
  }
}
