import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/services/gemini_service.dart' hide debugPrint;

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

    // 讀取原始圖片
    final file = File(imagePath);
    if (!await file.exists()) {
      debugPrint("錯誤：圖片檔案不存在: $imagePath");
      return;
    }

    final bytes = await file.readAsBytes();
    debugPrint("讀取圖片成功，大小: ${bytes.length} bytes");

    var originalImage = img.decodeImage(bytes);
    if (originalImage == null) {
      debugPrint("錯誤：無法解碼圖片");
      return;
    }

    // 🟢 核心修正 1：處理照片轉向問題 (EXIF 方向)
    // 這會把 iPhone 橫拍/直拍的旋轉資訊「烘焙」進像素，確保裁切座標正確
    originalImage = img.bakeOrientation(originalImage);
    debugPrint(
        "圖片處理完成 (含 EXIF 校正): ${originalImage.width}x${originalImage.height}");

    // 🟢 應用筆刷遮罩：在裁切之前，將塗掉的路徑繪製到圖片上（用白色填充）
    if (erasePaths.isNotEmpty) {
      debugPrint("=== 應用筆刷遮罩 ===");
      originalImage = _applyEraseMask(originalImage, displaySize, erasePaths);
      debugPrint("筆刷遮罩已應用");
    }

    final tempDir = await getTemporaryDirectory();
    debugPrint("臨時目錄: ${tempDir.path}");

    for (int i = 0; i < rects.length; i++) {
      debugPrint("=== 處理任務 $i ===");
      _updateTask(i,
          status: AnalysisStatus.processing, title: '正在裁切與辨識題目 ${i + 1}...');

      try {
        final rect = rects[i];
        debugPrint("框選區域 (螢幕座標): $rect");
        debugPrint("顯示區域大小: $displaySize");

        // 🟢 核心修正 2：精準計算 BoxFit.contain 的黑邊補償
        // 圖片在螢幕上使用 BoxFit.contain，可能有上下或左右黑邊
        final double imgAspect = originalImage.width / originalImage.height;
        final double viewAspect = displaySize.width / displaySize.height;

        double actualVisibleWidth, actualVisibleHeight;
        double offsetX = 0, offsetY = 0;

        if (viewAspect > imgAspect) {
          // 螢幕比圖片更寬 → 左右有黑邊
          actualVisibleHeight = displaySize.height;
          actualVisibleWidth = displaySize.height * imgAspect;
          offsetX = (displaySize.width - actualVisibleWidth) / 2;
        } else {
          // 螢幕比圖片更高 → 上下有黑邊
          actualVisibleWidth = displaySize.width;
          actualVisibleHeight = displaySize.width / imgAspect;
          offsetY = (displaySize.height - actualVisibleHeight) / 2;
        }

        debugPrint(
            "實際可見區域: ${actualVisibleWidth}x$actualVisibleHeight, 偏移: ($offsetX, $offsetY)");

        // 縮放比例：用「實際可見寬度」來計算
        final double scale = originalImage.width / actualVisibleWidth;
        debugPrint("縮放比例: $scale");

        // 座標轉換：先扣除黑邊偏移量，再縮放到圖片像素
        final int left = ((rect.left - offsetX) * scale)
            .toInt()
            .clamp(0, originalImage.width - 1);
        final int top = ((rect.top - offsetY) * scale)
            .toInt()
            .clamp(0, originalImage.height - 1);
        int width = (rect.width * scale).toInt();
        int height = (rect.height * scale).toInt();

        // 確保不超出圖片邊界
        width = width.clamp(1, originalImage.width - left);
        height = height.clamp(1, originalImage.height - top);

        debugPrint("裁切參數: left=$left, top=$top, width=$width, height=$height");

        // 執行裁切
        final croppedImage = img.copyCrop(
          originalImage,
          x: left,
          y: top,
          width: width,
          height: height,
        );
        debugPrint("裁切成功: ${croppedImage.width}x${croppedImage.height}");

        // 儲存裁切後的圖片
        final cropFileName =
            'crop_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final cropPath = p.join(tempDir.path, cropFileName);
        await File(cropPath).writeAsBytes(img.encodeJpg(croppedImage));
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
      // 讀取原始圖片
      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint("錯誤：圖片檔案不存在: $imagePath");
        _updateTask(taskIndex, status: AnalysisStatus.failed, title: '圖片檔案不存在');
        return;
      }

      final bytes = await file.readAsBytes();
      var originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        debugPrint("錯誤：無法解碼圖片");
        _updateTask(taskIndex, status: AnalysisStatus.failed, title: '無法解碼圖片');
        return;
      }

      // 處理 EXIF 方向
      originalImage = img.bakeOrientation(originalImage);

      final tempDir = await getTemporaryDirectory();

      _updateTask(taskIndex,
          status: AnalysisStatus.processing, title: '正在裁切題目...');

      // 計算裁切參數（與 _processQueue 中的邏輯相同）
      final double imgAspect = originalImage.width / originalImage.height;
      final double viewAspect = displaySize.width / displaySize.height;

      double actualVisibleWidth, actualVisibleHeight;
      double offsetX = 0, offsetY = 0;

      if (viewAspect > imgAspect) {
        actualVisibleHeight = displaySize.height;
        actualVisibleWidth = displaySize.height * imgAspect;
        offsetX = (displaySize.width - actualVisibleWidth) / 2;
      } else {
        actualVisibleWidth = displaySize.width;
        actualVisibleHeight = displaySize.width / imgAspect;
        offsetY = (displaySize.height - actualVisibleHeight) / 2;
      }

      final double scale = originalImage.width / actualVisibleWidth;
      final int left = ((rect.left - offsetX) * scale)
          .toInt()
          .clamp(0, originalImage.width - 1);
      final int top = ((rect.top - offsetY) * scale)
          .toInt()
          .clamp(0, originalImage.height - 1);
      int width = (rect.width * scale).toInt();
      int height = (rect.height * scale).toInt();
      width = width.clamp(1, originalImage.width - left);
      height = height.clamp(1, originalImage.height - top);

      // 執行裁切
      final croppedImage = img.copyCrop(
        originalImage,
        x: left,
        y: top,
        width: width,
        height: height,
      );

      // 儲存裁切後的圖片
      final cropFileName =
          'crop_${DateTime.now().millisecondsSinceEpoch}_$taskIndex.jpg';
      final cropPath = p.join(tempDir.path, cropFileName);
      await File(cropPath).writeAsBytes(img.encodeJpg(croppedImage));

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

  /// 應用筆刷遮罩：將屏幕座標的 Path 轉換為圖片像素座標，並繪製白色填充
  img.Image _applyEraseMask(
      img.Image originalImage, Size displaySize, List<Path> erasePaths) {
    // 計算座標轉換參數（與裁切邏輯相同）
    final double imgAspect = originalImage.width / originalImage.height;
    final double viewAspect = displaySize.width / displaySize.height;

    double actualVisibleWidth, actualVisibleHeight;
    double offsetX = 0, offsetY = 0;

    if (viewAspect > imgAspect) {
      // 螢幕比圖片更寬 → 左右有黑邊
      actualVisibleHeight = displaySize.height;
      actualVisibleWidth = displaySize.height * imgAspect;
      offsetX = (displaySize.width - actualVisibleWidth) / 2;
    } else {
      // 螢幕比圖片更高 → 上下有黑邊
      actualVisibleWidth = displaySize.width;
      actualVisibleHeight = displaySize.width / imgAspect;
      offsetY = (displaySize.height - actualVisibleHeight) / 2;
    }

    // 縮放比例：用「實際可見寬度」來計算
    final double scale = originalImage.width / actualVisibleWidth;

    // 創建一個新的圖片副本（不修改原圖）
    final maskedImage = img.copyResize(originalImage,
        width: originalImage.width, height: originalImage.height);

    // 將每個筆刷路徑轉換為圖片像素座標並繪製白色填充
    for (final screenPath in erasePaths) {
      final pathMetrics = screenPath.computeMetrics();

      for (final metric in pathMetrics) {
        // 遍歷路徑的每個點
        final pathPoints = <img.Point>[];

        // 採樣路徑點（每隔一小段採樣一次）
        for (double t = 0.0; t <= 1.0; t += 0.01) {
          final tangent = metric.getTangentForOffset(metric.length * t);
          if (tangent != null) {
            final screenPoint = tangent.position;
            // 座標轉換：先扣除黑邊偏移量，再縮放到圖片像素
            final pixelX = ((screenPoint.dx - offsetX) * scale)
                .toInt()
                .clamp(0, originalImage.width - 1);
            final pixelY = ((screenPoint.dy - offsetY) * scale)
                .toInt()
                .clamp(0, originalImage.height - 1);
            pathPoints.add(img.Point(pixelX, pixelY));
          }
        }

        // 使用筆刷寬度（30.0 屏幕單位）轉換為像素寬度
        final brushWidth =
            (30.0 * scale).toInt().clamp(5, 100); // 最小 5 像素，最大 100 像素

        // 繪製白色填充：對每個路徑點周圍的圓形區域進行填充
        for (final point in pathPoints) {
          final x = point.x;
          final y = point.y;
          final radius = brushWidth ~/ 2;

          // 繪製圓形白色填充
          for (int dy = -radius; dy <= radius; dy++) {
            for (int dx = -radius; dx <= radius; dx++) {
              final px = (x + dx).toInt();
              final py = (y + dy).toInt();
              if (px >= 0 &&
                  px < maskedImage.width &&
                  py >= 0 &&
                  py < maskedImage.height) {
                final distance = math.sqrt(dx * dx + dy * dy);
                if (distance <= radius) {
                  // 設置為白色像素
                  maskedImage.setPixel(px, py, img.ColorRgb8(255, 255, 255));
                }
              }
            }
          }
        }
      }
    }

    return maskedImage;
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
