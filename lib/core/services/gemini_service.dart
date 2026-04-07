import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' as foundation;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/app_environment.dart';
import '../database/models/mistake.dart';
import '../utils/latex_helper.dart';

const bool _enableVerboseGeminiLogs =
    bool.fromEnvironment('LB_VERBOSE_GEMINI_LOGS', defaultValue: false);

void debugPrint(String? message, {int? wrapWidth}) {
  if (!foundation.kDebugMode || !_enableVerboseGeminiLogs) return;
  foundation.debugPrint(message, wrapWidth: wrapWidth);
}

class GeminiService {
  static final GeminiService _instance = GeminiService._();
  factory GeminiService() => _instance;
  GeminiService._();

  // 🔐 編譯期 --dart-define 注入（勿將金鑰放進 assets）
  String get _apiKey => AppEnvironment.geminiApiKey;

  // 保存當前使用的模型名稱
  String _currentModelName = '';

  GenerativeModel? _model;
  bool _isInitialized = false;
  String? _lastError;
  String? _lastSimilarPracticeError;

  /// 獲取最後一次錯誤訊息
  String? get lastError => _lastError;
  String? get lastSimilarPracticeError => _lastSimilarPracticeError;

  /// 預設使用的模型（gemini-2.0-flash 是最新的免費模型）
  static const String _defaultModel = 'gemini-2.0-flash';
  static const String _defaultGeometrySolveModel = 'gemini-2.5-pro';

  GenerativeModel _createModel(String modelName) {
    return GenerativeModel(
      model: modelName,
      apiKey: _apiKey,
    );
  }

  /// 解題時可依情境覆蓋模型；預設仍沿用當前主模型。
  /// 優先序：
  /// 1. 幾何附圖專用模型 `GEMINI_SOLVE_MODEL_GEOMETRY_WITH_IMAGE`
  /// 2. 數學附圖專用模型 `GEMINI_SOLVE_MODEL_MATH_WITH_IMAGE`
  /// 3. 數學通用模型 `GEMINI_SOLVE_MODEL_MATH`
  /// 4. 當前主模型 / 預設模型
  String _resolveSolveModelName({
    required bool hasImage,
    required bool looksLikeMath,
    required bool looksLikeGeometry,
  }) {
    final geometryWithImageModel =
        AppEnvironment.geminiSolveModelGeometryWithImage;
    final mathModel = AppEnvironment.geminiSolveModelMath;
    final mathWithImageModel = AppEnvironment.geminiSolveModelMathWithImage;
    if (hasImage && looksLikeGeometry) {
      if (geometryWithImageModel.isNotEmpty) {
        return geometryWithImageModel;
      }
      return _defaultGeometrySolveModel;
    }
    if (hasImage && looksLikeMath && mathWithImageModel.isNotEmpty) {
      return mathWithImageModel;
    }
    if (looksLikeMath && mathModel.isNotEmpty) {
      return mathModel;
    }
    return _currentModelName.isNotEmpty ? _currentModelName : _defaultModel;
  }

  /// 初始化 Gemini 模型
  /// 注意：不再發送測試請求，直接創建模型實例
  Future<void> init() async {
    // 如果已經初始化成功，直接返回
    if (_isInitialized && _model != null) {
      debugPrint("✅ Gemini API 已經初始化，跳過重複初始化");
      return;
    }

    if (_apiKey.isEmpty) {
      _lastError =
          "Gemini API Key 未設定，請以 --dart-define=GEMINI_API_KEY=... 注入";
      debugPrint("❌ $_lastError");
      _isInitialized = false;
      return;
    }

    debugPrint("🔧 開始初始化 Gemini API...");
    debugPrint("   API Key 長度: ${_apiKey.length} 字元");
    debugPrint(
        "   API Key 前4碼: ${_apiKey.substring(0, math.min(4, _apiKey.length))}...");
    debugPrint("   使用模型: $_defaultModel");

    try {
      // 直接創建模型實例，不發送測試請求
      // 這樣可以節省配額，在實際調用時才會驗證
      _model = _createModel(_defaultModel);

      _isInitialized = true;
      _currentModelName = _defaultModel;
      _lastError = null;
      debugPrint("✅ Gemini API 已初始化 (使用 $_defaultModel)");
      debugPrint("   注意：實際 API 連線將在首次調用時驗證");
    } catch (e) {
      _isInitialized = false;
      _lastError = "初始化失敗: $e";
      debugPrint("❌ $_lastError");
    }
  }

  /// 檢查是否已初始化
  bool get isReady => _isInitialized && _model != null;

  /// 獲取 finishReason 的描述
  String _getFinishReasonDescription(FinishReason? reason) {
    if (reason == null) return "未知";
    switch (reason) {
      case FinishReason.stop:
        return "正常完成";
      case FinishReason.maxTokens:
        return "達到最大 token 限制";
      case FinishReason.safety:
        return "被安全過濾器阻擋";
      case FinishReason.recitation:
        return "可能涉及版權問題";
      case FinishReason.other:
        return "其他原因";
      case FinishReason.unspecified:
        return "未指定原因";
    }
  }

  /// 使用 Gemini 進行 OCR 辨識圖片中的文字（替代 Mathpix）
  /// [imageFile] 需要辨識的圖片檔案
  /// 返回辨識的文字，如果失敗返回 null
  Future<String?> recognizeImage(File imageFile) async {
    // 如果尚未初始化，嘗試初始化
    if (!isReady) {
      debugPrint("⚠️ GeminiService 尚未初始化，嘗試自動初始化...");
      try {
        await init();
        if (!isReady) {
          debugPrint("❌ 自動初始化失敗: ${_lastError ?? '未知錯誤'}");
          return null;
        }
        debugPrint("✅ 自動初始化成功");
      } catch (e) {
        debugPrint("❌ 自動初始化時發生錯誤: $e");
        return null;
      }
    }

    // 讀取圖片
    Uint8List imageBytes;
    try {
      imageBytes = await imageFile.readAsBytes();
      debugPrint("📷 已載入圖片: ${imageFile.path} (${imageBytes.length} bytes)");
    } catch (e) {
      debugPrint("⚠️ 無法讀取圖片檔案: $e");
      return null;
    }

    const prompt = '''
請辨識這張圖片中的文字內容。這是一道數學/自然科學/社會科學/語文題目。

**⚠️ 重要：必須完整保留所有數學結構，優先輸出標準 LaTeX！**

請直接輸出題目的完整文字內容，包括：
1. 題目敘述
2. 選項（如果有的話）
3. **數學符號與結構**（必須完整保留）
4. **數學公式**（優先使用標準 LaTeX，行內公式用 \\( ... \\)，區塊公式用 \\[ ... \\]）

**特別注意**：
- 如果題目包含根號，請優先輸出為 `\\sqrt{...}`，且必須完整包住整個被開方式
- 如果題目包含線段、射線、向量等，請使用標準 LaTeX，例如線段 `\\overline{AB}`、向量 `\\vec{AB}`
- 如果題目包含指數、分數、上下標，請使用標準 LaTeX，例如 `x^2`、`\\frac{a}{b}`、`a_n`
- 不要把數學式改寫成口語，例如「根號」、「平方」
- **選擇題選項（(A)(B)(C)(D)、甲/乙/丙/丁 等）**：只要圖上能讀到文字或數字，就必須**完整逐項寫出**，含選項內的算式（用 LaTeX）；**禁止**用「（如圖）」代替整組選項或單一選項。
- 「（如圖）」**僅限**於：幾何示意圖、函數圖形、統計圖、地圖、照片類題幹等**無法**用純文字／LaTeX 合理還原的視覺內容；單行文字選項不屬於此類。
- **禁止**在題幹或選項已完整寫出時，於句尾或另起一行再加「（如圖）」「(如圖)」：本 App 會另顯示原圖，該贅字對使用者沒有幫助。
- 請保持題目的原始格式和結構
- 只輸出題目文字，不要添加任何解釋或分析
''';

    try {
      debugPrint("🔍 Gemini 正在辨識圖片...");

      final contentList = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await _model!.generateContent(contentList).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Gemini OCR 請求超時');
        },
      );

      final text = response.text;
      if (text == null || text.isEmpty) {
        debugPrint("❌ Gemini OCR 返回空結果");
        return null;
      }

      debugPrint(
          "✅ Gemini OCR 完成: ${text.substring(0, math.min(100, text.length))}...");

      // 添加檢查數學符號的調試日誌
      final hasMathSymbols = text.contains('√') ||
          text.contains('²') ||
          text.contains('³') ||
          text.contains('√(') ||
          text.contains('根號') ||
          text.contains('平方');
      debugPrint("   📊 數學符號檢查: ${hasMathSymbols ? '✅ 包含數學符號' : '❌ 未發現數學符號'}");
      if (hasMathSymbols) {
        // 提取包含數學符號的片段
        final mathPattern = RegExp(r'.{0,50}[√²³√(].{0,50}');
        final matches = mathPattern.allMatches(text);
        if (matches.isNotEmpty) {
          debugPrint("   📊 發現的數學表達式片段:");
          matches.take(3).forEach((match) {
            debugPrint("      - ${match.group(0)}");
          });
        }
      } else {
        debugPrint("   ⚠️ 警告：OCR 結果中未發現數學符號（√、²、³等），可能影響科目判斷");
      }

      final normalized = LatexHelper.normalizeModelText(
        text,
        preserveLineBreaks: true,
      );
      if (normalized.isEmpty) return null;
      return LatexHelper.stripEditorialFigurePhrases(normalized);
    } catch (e) {
      debugPrint("❌ Gemini OCR 失敗: $e");
      return null;
    }
  }

  /// 核心方法：傳入題目文字（和可選的圖片），回傳結構化解題資料
  /// [questionText] OCR 辨識的題目文字
  /// [imageFile] 可選的圖片檔案，用於多模態輸入（幫助理解圖表、幾何圖形等）
  /// [forceAttachImageFromPipeline] 由上游流程強制要求附圖，用於數學 OCR 管道
  /// 返回 Map 表示成功，返回 null 表示失敗（會包含錯誤訊息在 debugPrint 中）
  Future<Map<String, dynamic>?> solveProblem(
    String questionText, {
    File? imageFile,
    bool forceAttachImageFromPipeline = false,
  }) async {
    final normalizedQuestionText = LatexHelper.normalizeModelText(
      questionText,
      preserveLineBreaks: true,
    );
    if (normalizedQuestionText.isEmpty) {
      debugPrint("❌ 題目文字為空，無法分析");
      return null;
    }

    // 如果尚未初始化，嘗試初始化
    if (!isReady) {
      debugPrint("⚠️ GeminiService 尚未初始化，嘗試自動初始化...");
      try {
        await init();
        if (!isReady) {
          debugPrint("❌ 自動初始化失敗: ${_lastError ?? '未知錯誤'}");
          return null;
        }
        debugPrint("✅ 自動初始化成功");
      } catch (e) {
        debugPrint("❌ 自動初始化時發生錯誤: $e");
        return null;
      }
    }

    // 再次檢查（初始化後可能仍然失敗）
    if (!isReady) {
      final errorMsg = _apiKey.isEmpty
          ? "Gemini API Key 未設定，請以 --dart-define=GEMINI_API_KEY=... 注入"
          : "GeminiService 初始化失敗: ${_lastError ?? '未知錯誤'}";
      debugPrint("❌ $errorMsg");
      return null;
    }

    // 檢查圖片是否存在
    Uint8List? imageBytes;
    if (imageFile != null && await imageFile.exists()) {
      try {
        imageBytes = await imageFile.readAsBytes();
        debugPrint("📷 已載入圖片: ${imageFile.path} (${imageBytes.length} bytes)");
      } catch (e) {
        debugPrint("⚠️ 無法讀取圖片檔案: $e");
        imageBytes = null;
      }
    }

    // 省成本：OCR 已含完整選擇題選項且無「需看圖」線索時，可略過附圖（仍保留完整文字 prompt）。
    // - GEMINI_SOLVE_OMIT_IMAGE_WHEN_TEXT_COMPLETE=0：關閉「文字完整就略圖」
    // - GEMINI_SOLVE_ALWAYS_ATTACH_IMAGE=1：強制一律附圖（全科目）
    // - GEMINI_SOLVE_ALWAYS_ATTACH_IMAGE_FOR_MATH=1：僅在 OCR 判為數學題時強制附圖（解題前尚無 subject，故用字串啟發式）
    Uint8List? bytesForMultimodal = imageBytes;
    final looksLikeMath = _ocrLooksLikeMath(normalizedQuestionText);
    final looksLikeGeometry = _ocrLooksLikeGeometryMath(normalizedQuestionText);
    final hasMustAttachSignals =
        _containsMustAttachImageSignals(normalizedQuestionText);
    if (imageBytes != null) {
      final forceImageAll =
          AppEnvironment.geminiSolveAlwaysAttachImage == '1';
      final forceImageMathOnly =
          AppEnvironment.geminiSolveAlwaysAttachImageForMath == '1';
      final forceImage = forceImageAll ||
          forceAttachImageFromPipeline ||
          (forceImageMathOnly && looksLikeMath);
      final omitEnv = AppEnvironment.geminiSolveOmitImageWhenTextComplete;
      final allowOmit = !forceImage &&
          (omitEnv.isEmpty ? true : omitEnv != '0');
      final shouldOmitForTokenSavings =
          _shouldOmitProblemImageForTokenSavings(normalizedQuestionText);
      if (allowOmit && shouldOmitForTokenSavings) {
        bytesForMultimodal = null;
        debugPrint(
            '💡 本次解題略過附圖（OCR 已含選項／題意足夠），以節省映像 token');
      } else if (forceAttachImageFromPipeline) {
        debugPrint('💡 數學流程：由上游管道強制附圖（forceAttachImageFromPipeline）');
      } else if (forceImageMathOnly && !forceImageAll && looksLikeMath) {
        debugPrint('💡 數學題（OCR 啟發式）：強制附圖（GEMINI_SOLVE_ALWAYS_ATTACH_IMAGE_FOR_MATH）');
      } else if (forceImageAll) {
        debugPrint('💡 全域設定：強制附圖（GEMINI_SOLVE_ALWAYS_ATTACH_IMAGE）');
      }

      debugPrint('🧾 附圖決策: imageBytes=${imageBytes.length} bytes, '
          'forceAll=$forceImageAll, '
          'forceFromPipeline=$forceAttachImageFromPipeline, '
          'forceMathOnly=$forceImageMathOnly, '
          'looksLikeMath=$looksLikeMath, '
          'mustAttachSignals=$hasMustAttachSignals, '
          'allowOmit=$allowOmit, '
          'bytesForMultimodal=${bytesForMultimodal != null ? 'attached' : 'omitted'}');
    } else {
      debugPrint('🧾 附圖決策: 無可用圖片輸入，略過多模態附圖');
    }

    // 定義 Prompt（放在 try 外面，讓 catch 也能訪問）
    String imageInstruction = '';
    if (bytesForMultimodal != null) {
      imageInstruction = '''

**重要：您同時收到了題目的原始圖片。請仔細觀察圖片中的：
1. 幾何圖形（三角形、圓形、多邊形等）的形狀和位置關係
2. 座標圖、函數圖形中的線條、曲線和趨勢
3. 圖表中的數據、標籤和單位
4. 表格、圖片等無法通過文字完整描述的視覺元素

請結合圖片中的視覺資訊和 OCR 辨識的文字來提供更準確的分析。如果圖片中的資訊與 OCR 文字有差異，請優先參考圖片中的實際內容。

**介面已會顯示原題照片**：若題幹與選項已能用繁體中文＋LaTeX 完整寫出，**禁止**在 `question_text` 句末或獨立一行再加「（如圖）」「(如圖)」等贅語；僅在**真的無法**用文字還原的圖表區塊保留一句（如數線選項全在圖上、且文字無 (A)～(D) 可寫時）。

**選項與「（如圖）」的分界（必須遵守）**：
- 若題目有 **(A)(B)(C)(D)**、**甲/乙/丙/丁** 等選項，且選項內容是**可讀的文字、數字或算式**，請在 `question_text` 中 **全部寫出**，必要時依圖片補齊 OCR 漏掉的選項；**絕對禁止**用「（如圖）」取代選項列。
- 「（如圖）」**只可用於**：幾何圖、函數圖、統計圖、地圖、複雜表格等 **無法** 用純文字＋LaTeX 合理還原的部分；不適用於單純的選擇題選項行。
- **數線／示意圖多選題**：不要用 `\\begin{array}` 或 `tabular` 把 (A)～(D) 排成表格，也**禁止**在該環境的儲存格內再寫 `\$...\$`（會造成排版器錯亂）。請改為：題幹維持 LaTeX，選項處只寫「（如圖）」一句，或簡短文字描述各選項（例如「(A) 左開右閉…」），勿輸出殘缺 LaTeX。

**有附圖時的解題規則（必須遵守）**：
- 在 `標準解法` 一開始，先用 1～3 句簡要整理「圖中可直接讀到的已知條件」；例如點的位置、角度、邊長、平行/垂直、交點、函數圖形趨勢、座標關係。
- 若圖片與 OCR 文字有衝突，`標準解法` 必須明確採用圖片中較清楚、較完整的一方，不可默默混用。
- 不可自行腦補圖上未標示的長度、角度、相似、全等等關係；若圖與文字仍不足以唯一決定答案，請在 `標準解法` 清楚指出資訊不足，不要假設隱含條件。
- 若是選擇題，`標準解法` 的最後一句必須明確寫出對應選項（例如「所以答案是 (B)」），且前面的推理必須能支持該選項。

''';
    }

    final prompt = '''
你是一位具有 15 年教學經驗的台灣國中/高中老師，熟悉會考與學測題型分類，對各科目課本內容非常熟悉。

$imageInstruction
以下是透過 OCR 辨識的題目文字：
「$normalizedQuestionText」

請你【嚴格】依照下列規則分析題目，並以 JSON 格式輸出，不要包含任何 Markdown。

====================
【重要分類規則（務必遵守）】
====================

1️⃣ subject 判斷規則（必須根據台灣國高中課本內容判斷）：
        
**⚠️ 第一步：依題目語言結構判斷是否為「英文」科目（優先於圖片）**

- 如果 OCR 辨識的題目文字「幾乎全部由英文字母、數字和標點組成，且完全沒有任何中文字」，你必須將 subject 判斷為「英文」，即使題目圖片中還有其他語言的內容。
- 如果 OCR 辨識的題目文字「完全沒有英文字母 A～Z」，你不得將 subject 判斷為「英文」，即使題目圖片中有英文句子或單字。
- 圖片中的資訊可以用來理解題意與還原公式，但不能推翻以上兩條規則。

**⚠️ 第二步：強制檢查數學符號（最高優先級）**

在判斷科目之前，**必須先檢查**題目中是否包含以下任何數學符號或運算：
- **根號符號**：√、√(、根號、sqrt、開根號、根式
- **指數符號**：²、³、ⁿ、^2、^3、平方、立方、次方、冪
- **運算符號**：+、−、×、÷、=、<、>、≥、≤、≠、±
- **數學表達式**：包含根號的算式（如 √9、√(-9)²、(-√16)²）、次方運算（如 2²、3³）

**⚠️ 如果題目包含上述任何數學符號或表達式，無論題目中是否有中文文字（如「判斷」、「選擇」、「下列」等），都必須判斷為「數學」！**

**範例（必須判斷為「數學」）：**
- ✅ 「下列哪些敘述是正確的？(甲) √(-9)² = -9 (乙) (-√16)² = 16」→ **數學**（包含 √、²）
- ✅ 「判斷哪些算式正確：√9 + 16 = √9 + √16」→ **數學**（包含 √、+）
- ✅ 「選擇正確答案：√9 × 16 = √9 × √16」→ **數學**（包含 √、×）
- ✅ 「判斷下列哪些正確：(甲) √3×(√50-√18)」→ **數學**（包含 √、×、-）

**判斷流程：**
步驟 1：**強制檢查數學符號**（√、²、³、次方、根號等）→ 如果包含，**直接判斷為「數學」，結束判斷**
步驟 2：觀察題目的核心知識領域
步驟 3：對照台灣國高中各科目課本的主要內容
步驟 4：選擇最符合的科目

**各科目判斷標準：**

📚 **數學**（優先判斷）：
- **最優先判斷特徵**（只要符合以下任一項，就**必須**判斷為「數學」）：
  1. **數學運算符號**：包含 +、−、×、÷、=、<、>、≥、≤、≠、√（根號）、√(、²（平方）、³（立方）、ⁿ（次方）、∑（求和）、∫（積分）、π（圓周率）、根號、開根號、平方、立方、次方、冪
  2. **根號運算式**：任何包含 √ 的算式，如 √9、√(-9)²、(-√16)²、√9 + 16、√9 × 16、√(9+16)
  3. **指數運算式**：任何包含 ²、³、ⁿ、^2、^3 的算式
  4. **數學公式**：包含變數（x、y、a、b、n 等）、方程式、不等式、函數式（如 f(x)、g(x)）
  5. **運算過程**：需要進行計算、化簡、因式分解、展開等數學運算
  6. **幾何圖形描述**：三角形、圓、正方形、多邊形、面積、周長、角度、座標、向量等
  7. **數學概念**：機率、統計、數列、等差、等比、三角函數、對數、指數等專有名詞
  
- **關鍵字**：計算、解題、算出來、算式的值、化簡、因式分解、展開、方程式、函數、圖形、三角形、圓、面積、體積、機率、統計、代數、幾何、根號、平方、立方、次方、相等、等於、**判斷（當後面跟的是數學算式時）**、**選擇（當選項是數學算式時）**
  
- **範例**：
  - ✅ 根號運算題：「√3×(√50-√18)的值與下列選項哪一個算式的值相等？」→ 數學
  - ✅ 根號判斷題：「下列哪些敘述是正確的？(甲) √(-9)² = -9 (乙) (-√16)² = 16」→ **數學**（即使有「判斷」和「正確」等詞）
  - ✅ 解方程式：「解一元二次方程式 x²-5x+6=0」→ 數學
  - ✅ 計算題：「求面積、求體積、計算機率」→ 數學
  - ✅ 函數圖形：「畫出函數 y=x² 的圖形」→ 數學
  
- **⚠️ 特別注意**：
  - **只要題目包含 √（根號）、²（平方）等數學符號，或包含「根號」、「平方」、「次方」等數學關鍵字，就必須判斷為「數學」，即使題目中有「判斷」、「選擇」、「正確」、「錯誤」等文字敘述**
  - **不要因為題目有「判斷哪些敘述正確」或「選擇正確答案」這樣的文字，就誤判為「國文」或「公民/歷史/地理」**
  - 即使題目中有其他文字的敘述（如「同學」、「選項」、「判斷」、「選擇」等），只要核心是數學運算，仍然是「數學」

📝 **國文**：
- 特徵：語文理解、修辭、文法、文學作品、文言文、詩詞、成語、字音字形
- 關鍵字：文言文、白話文、修辭法、語法、句型、成語、詩詞、文學作品、作者、文意理解
- 範例：文言文翻譯、修辭判斷、語病修改、成語填空、詩詞賞析

🔤 **英文**：
- 特徵：英文單字、文法、閱讀理解、句型結構、時態、語態
- 關鍵字：English、grammar、tense、vocabulary、reading comprehension、sentence pattern
- 範例：文法選擇、單字填空、閱讀測驗、句型轉換、時態判斷

🔬 **自然**：
- 特徵：物理、化學、生物、地科等自然科學概念
- 關鍵字：物理（力、能量、電、光、熱、波、運動）、化學（元素、化合物、反應、酸鹼、氧化還原）、生物（細胞、遺傳、生態、演化）、地科（地球、天氣、天文、地質）
- 範例：物理計算題、化學反應式、生物構造圖、地科觀測題
- **注意**：如果題目明確是單一學科（如純物理、純化學），仍歸類為「自然」，因為國高中「自然」科涵蓋物理、化學、生物、地科

🗺️ **地理**：
- 特徵：地形、氣候、國家、城市、經濟活動、地圖判讀等地理學科內容
- 關鍵字：地形、氣候、國家、城市、經濟活動、地圖判讀、地理位置、經緯度、人口、資源、環境、區域
- 範例：地圖判讀、國家位置、地形分析、氣候特徵、經濟活動、地理位置判斷
- **注意**：包含地圖、地理位置、地形、氣候、國家城市等，屬於「地理」

📜 **歷史**：
- 特徵：朝代、事件、人物、年代、戰爭、政治制度等歷史學科內容
- 關鍵字：朝代、事件、人物、年代、戰爭、政治制度、歷史事件、古代、近代、現代、史料、文物
- 範例：歷史事件分析、朝代演變、人物事蹟、戰爭經過、政治制度變遷
- **注意**：包含歷史事件、朝代、人物、年代等，屬於「歷史」

⚖️ **公民**：
- 特徵：法律、政治、經濟、社會制度、權利義務等公民學科內容
- 關鍵字：法律、政治、經濟、社會制度、權利義務、民主、人權、政府、憲法、選舉、政策
- 範例：法律概念解釋、政治制度說明、經濟活動分析、權利義務判斷、社會議題討論
- **注意**：包含法律概念、政治制度、經濟活動、權利義務等，屬於「公民」

❓ **其他**：
- 僅在題目完全不符合以上七個科目時使用
- 例如：邏輯推理題、智力測驗、非學科相關題目

**⚠️ 重要判斷原則（嚴格遵守）：**
1. **數學優先原則**：如果題目包含數學運算符號（√、²、+、−、×、÷、= 等）或需要數學計算，優先判斷為「數學」
2. **優先看題目內容**：不要只看題目來源（例如從數學考卷來的，但內容是地理地圖題 → 應判斷為「地理」）
3. **知識領域優先**：題目主要考查的知識領域是哪個科目的內容
4. **課本依據**：對照台灣國高中各科目課本的章節內容來判斷
5. **如果題目包含多個領域**：選擇主要考查的核心領域
6. **無法判斷時**：優先選擇最可能的科目，不要輕易使用「其他」

**判斷順序建議：**
步驟 1：檢查是否有數學運算符號或需要數學計算 → 如果是，直接判斷為「數學」
步驟 2：檢查是否包含地圖、地理位置、地形、氣候 → 如果是，判斷為「地理」
步驟 3：檢查是否包含歷史事件、朝代、人物、年代 → 如果是，判斷為「歷史」
步驟 4：檢查是否包含法律、政治、經濟、權利義務 → 如果是，判斷為「公民」
步驟 5：檢查是否為語文理解、修辭、文言文 → 如果是，判斷為「國文」
步驟 6：檢查是否為英文單字、文法、閱讀 → 如果是，判斷為「英文」
步驟 7：檢查是否為物理、化學、生物、地科 → 如果是，判斷為「自然」

**常見誤判情況與正確判斷：**
- ❌ 錯誤：題目有數字計算 → 數學
- ✅ 正確：題目內容是地理位置的數字（如經緯度、人口數）→ 地理；題目需要進行數學運算（如 √3×(√50-√18)）→ 數學

- ❌ 錯誤：題目有圖表 → 數學
- ✅ 正確：題目是地圖判讀 → 地理；題目是統計圖但考查社會現象 → 公民；題目是函數圖形或幾何圖形 → 數學

- ❌ 錯誤：題目有中文敘述或提到「同學」、「選項」→ 國文或公民/歷史/地理
- ✅ 正確：題目是中文但考查地理知識 → 地理；題目是中文但考查歷史知識 → 歷史；題目是中文但考查公民知識 → 公民；題目考查數學概念但用中文描述（如「算式的值」、「化簡」）→ 數學

- ❌ 錯誤：題目包含「判斷」、「選擇」等動詞 → 公民/歷史/地理或國文
- ✅ 正確：題目要求「判斷哪個算式正確」、「選擇正確答案」，但核心是數學運算 → 數學；題目要求「判斷地理位置」→ 地理；題目要求「判斷歷史事件」→ 歷史；題目要求「判斷法律概念」→ 公民

2️⃣ grade_level 必須明確判斷，只能選：
- 國一
- 國二
- 國三
- 高一
- 高二
- 高三
- 不確定（僅在無法判斷時使用）

**判斷依據：**
- 題目難度（國中 vs 高中）
- 知識範圍（例如：三角函數通常在高中）
- 題目來源（如果題目註明會考、學測等）
- 解題方法複雜度

3️⃣ category（題型分類）：

**數學題型**（僅當 subject = "數學" 時使用以下分類）：
- 數與式
- 一元一次方程式
- 二元一次方程式
- 一元二次方程式
- 函數與圖形
- 比例與百分比
- 指數與對數
- 數列
- 平面幾何
- 立體幾何
- 三角形
- 相似與全等
- 三角函數
- 向量
- 機率
- 統計
- 不等式
- 其他（僅在完全不符合以上時使用）

**國文題型**（僅當 subject = "國文" 時）：
- 字音字形
- 語詞應用
- 成語運用
- 修辭判斷
- 文法句型
- 文意理解
- 文言文閱讀
- 白話文閱讀
- 詩詞賞析
- 其他

**英文題型**（僅當 subject = "英文" 時）：
- 單字
- 文法
- 句型結構
- 閱讀理解
- 克漏字
- 文意選填
- 其他

**自然題型**（僅當 subject = "自然" 時）：
- 物理-力學
- 物理-熱學
- 物理-光學
- 物理-電磁學
- 化學-物質結構
- 化學-化學反應
- 化學-酸鹼鹽
- 生物-細胞與遺傳
- 生物-生物多樣性
- 地科-地球科學
- 其他

**地理題型**（僅當 subject = "地理" 時）：
- 台灣地理
- 世界地理
- 地圖判讀
- 地形與氣候
- 人口與資源
- 經濟活動
- 區域發展
- 其他

**歷史題型**（僅當 subject = "歷史" 時）：
- 台灣史
- 中國史
- 世界史
- 古代史
- 近代史
- 現代史
- 其他

**公民題型**（僅當 subject = "公民" 時）：
- 法律與政治
- 經濟
- 社會制度
- 權利義務
- 民主與人權
- 政府與憲法
- 其他

⚠️ 禁止使用「一般」「綜合」「基礎」這類模糊分類。

4️⃣ chapter（章節名稱）請使用「教科書實際章節語言」，例如：
- 一元一次方程式的應用
- 函數圖形與性質
- 三角形的全等性質
- 機率的基本概念

若無法確定，請填：
「待確認章節」

5️⃣ key_concepts：
- 請列出 2～4 個「可用來教學生的核心概念」
- 必須是具體可學習的概念（不可太抽象）

====================
【解題輸出要求】
====================

solutions 陣列中必須包含：

A. 標準解法  
- 使用「一步一式」
- 每一步都解釋為什麼這樣做
- 適合國中/高中生閱讀

B. 易錯提醒  
- 指出學生最常錯的 2～3 個地方
- 說明錯誤原因（不是只說「小心計算錯誤」）

====================
【最終輸出格式（嚴格遵守）】
====================

⚠️ question_text 內容過濾規則（必須遵守）：
0. **最高優先**：若 OCR 已寫出題幹與 **(A)～(D)**（或甲～丁）選項內容，`question_text` 必須**逐字保留選項列**，**絕對禁止**用「（如圖）」「(如圖)」取代任一選項或整段選項；也**禁止**在句尾再補「（如圖）」（使用者介面已會顯示掃描圖，該字樣毫無意義）。
1. 移除明顯的 OCR 雜訊：亂碼字元、破碎符號、無意義的字元組合（如「䟎」「署考数学」等）。
2. 移除非題目內容：頁碼、考卷標頭（如「111學年度第一次段考」）、學校名稱、浮水印文字等，這些不是題目本身的一部分，不應出現在 question_text 中。
3. 處理殘缺的 LaTeX 片段：如果有明顯殘缺或亂碼的 LaTeX 語法（例如只有半截的指令、缺少花括號的片段），請優先根據圖片或上下文還原為正確的數學公式。
4. **選擇題選項**：凡圖中可見的 (A)～(D) 或類似選項，必須完整列入 question_text；不得省略或改寫成「（如圖）」。
5. 「（如圖）」僅用於無法用文字＋LaTeX 還原的圖形、統計圖、地圖、複雜表格等；**不**用於選項文字。
6. **數線圖示選擇題**：`question_text` 內**不要**使用 `\\begin{array}`／`tabular` 包 (A)～(D)；若無法用文字描述各數線，題幹後接一句「（如圖）」即可。
7. **贅字「（如圖）」**：凡 (A)～(D)（或甲～丁）選項文字已在 `question_text` 中出現者，**不得**再在末尾加「（如圖）」；使用者介面已會顯示掃描圖。
8. 回退原則：如果移除或修改某段內容會導致題目不完整或失去意義，則保留該段原文不做任何修改，確保題目的完整性優先於清理。

{
  "question_text": "優化後的題目文字（依上方過濾規則清理；可讀選項必須寫齊；僅對無法文字化的圖表使用「（如圖）」；數學公式統一使用 \\( ... \\) 和 \\[ ... \\]）",
  "subject": "...",
  "grade_level": "...",
  "category": "...",
  "chapter": "...",
  "key_concepts": ["...", "..."],
        "solutions": [
          {
            "title": "標準解法",
      "content": "..."
          },
          {
            "title": "易錯提醒",
      "content": "..."
    }
  ]
}

====================
【LaTeX 格式規則（嚴格遵守）】
====================

1. **行內公式**: 所有行內數學公式 **必須** 使用 \\( ... \\) 進行包裹，且必須確保 \\( 和 \\) 成對出現。例如：\\( x^2 + y^2 = z^2 \\)。**絕對禁止** 使用 \${...}\$、((...)) 或任何其他非標準符號作為公式分隔符。
2. **區塊公式**: 所有獨立成行的區塊數學公式 **必須** 使用 \\[ ... \\] 進行包裹，且必須確保 \\[ 和 \\] 成對出現。例如：\\[ \\frac{a}{b} \\]。**絕對禁止** 使用 \$\${...}\$\$、\\begin{...} 環境或任何其他非標準符號。
3. **禁止的符號**: **絕對禁止** 使用 \${...}\$、\$\${...}\$\$、((...)) 或任何其他非標準符號作為公式分隔符。
4. **換行**: 在 Markdown 中，使用標準的單一換行符 \\n 來換行。**絕對禁止** 在公式內外使用單一反斜線或雙反斜線來表示換行。**絕對禁止** 在文字末尾添加反斜線。
5. **指令**: 所有 LaTeX 指令前 **必須** 有一個且只有一個反斜線。例如，使用 \\frac，而不是 frac 或 \\\\frac。
6. **完整性**: 確保所有 LaTeX 指令都是 KaTeX 支援的標準指令，並且所有括號 {}, (), [] 都是完整閉合的。**特別注意**：所有 \\( 必須有對應的 \\)，所有 \\[ 必須有對應的 \\]。
7. **水平線**: **嚴禁** 使用 --- 或 *** 等符號作為分隔線或裝飾。請使用空行來分隔段落。
8. **根號與線段**: `\\sqrt{}` 必須完整包住整個被開方式，不可只包第一個 token；幾何線段請使用 `\\overline{AB}` 這類標準 LaTeX，不要用組合字元、底線或純文字近似。

9. **輸出前自我檢查（強制執行）**: 在生成最終 JSON 輸出之前，你 **必須** 對所有包含數學公式的欄位進行以下檢查：\n   - 檢查一：所有 \\left 是否有對應的 \\right，且都在 \\( \\) 或 \\[ \\] 內。\n   - 檢查二：所有 \\frac、\\sqrt、\\overline 等指令是否都在 \\( \\) 或 \\[ \\] 內。\n   - 檢查三：所有括號 {}、()、[] 是否完整閉合。\n   - 檢查四：`\\sqrt{}` 是否包住完整被開方式，而不是半截公式。\n   如果發現任何違規，請在輸出前自行修正。

請確保所有內容都是繁體中文，並嚴格遵守以上所有規則。
''';

    try {
      debugPrint("🧠 Gemini 正在分析題目...");
      debugPrint(
          "   API Key 狀態: ${_apiKey.isNotEmpty ? '已載入 (${_apiKey.substring(0, math.min(4, _apiKey.length))}...)' : '未載入'}");
      debugPrint(
          "   模型狀態: ${_model != null ? '已初始化 ($_currentModelName)' : '未初始化'}");
      final imageBytesLength = bytesForMultimodal?.length ?? 0;
      debugPrint(
          "   圖片狀態: ${bytesForMultimodal != null ? '已載入 ($imageBytesLength bytes)' : '無圖片'}");

      // 添加檢查 OCR 文字中是否包含數學符號
      debugPrint("   📝 OCR 文字長度: ${normalizedQuestionText.length} 字元");
      debugPrint(
          "   📝 OCR 文字預覽: ${normalizedQuestionText.substring(0, math.min(200, normalizedQuestionText.length))}...");
      final hasMathSymbolsInText = normalizedQuestionText.contains('√') ||
          normalizedQuestionText.contains('²') ||
          normalizedQuestionText.contains('³') ||
          normalizedQuestionText.contains('√(') ||
          normalizedQuestionText.contains('根號') ||
          normalizedQuestionText.contains('平方');
      debugPrint(
          "   📊 OCR 文字中的數學符號檢查: ${hasMathSymbolsInText ? '✅ 包含數學符號' : '❌ 未發現數學符號'}");
      if (!hasMathSymbolsInText && bytesForMultimodal == null) {
        debugPrint("   ⚠️ 警告：OCR 文字中沒有數學符號，且本次請求未附圖，可能導致科目判斷錯誤！");
      } else if (!hasMathSymbolsInText && bytesForMultimodal != null) {
        debugPrint("   💡 提示：OCR 文字中沒有數學符號，但已附圖，Gemini 可直接看圖判斷");
      }

      final selectedModelName = _resolveSolveModelName(
        hasImage: bytesForMultimodal != null,
        looksLikeMath: looksLikeMath,
        looksLikeGeometry: looksLikeGeometry,
      );
      final usingSolveOverrideModel = selectedModelName != _currentModelName;
      final requestModel = usingSolveOverrideModel
          ? _createModel(selectedModelName)
          : _model!;
      final solveModelReason = looksLikeGeometry
          ? '幾何解題'
          : (looksLikeMath ? '數學解題' : '通用解題');
      debugPrint(
          "   🎯 本次解題模型: $selectedModelName${usingSolveOverrideModel ? '（$solveModelReason）' : ''}");

      // 發送請求（多模態：文字 + 圖片）
      final List<Content> contentList;
      if (bytesForMultimodal != null) {
        // 使用多模態輸入：文字 + 圖片
        contentList = [
          Content.multi([
            TextPart(prompt),
            DataPart('image/jpeg', bytesForMultimodal),
          ])
        ];
        debugPrint("📤 發送請求到 Gemini API（多模態：文字 + 圖片）...");
      } else {
        // 僅文字輸入
        contentList = [Content.text(prompt)];
        debugPrint("📤 發送請求到 Gemini API（僅文字）...");
      }
      debugPrint("   Prompt 長度: ${prompt.length} 字元");

      final response = await requestModel.generateContent(contentList);

      debugPrint("📥 Gemini API 回應狀態:");
      debugPrint(
          "   response.text: ${response.text != null ? '有內容 (${response.text!.length} 字元)' : 'null'}");
      debugPrint(
          "   response.candidates.length: ${response.candidates.length}");

      // 3. 解析結果
      if (response.text != null && response.text!.isNotEmpty) {
        debugPrint(
            "📥 Gemini 回應原始文字 (前100字): ${response.text!.substring(0, math.min(100, response.text!.length))}...");
        // 清理一下可能多餘的符號 (Gemini 有時還是會加 ```json)
        String text = response.text!;
        if (text.contains('```')) {
          text = text.replaceAll(RegExp(r'```json\n?'), '');
          text = text.replaceAll('```', '');
        }
        text = text.trim();

        // 🔧 修復：修復 JSON 中的 LaTeX 轉義問題
        // Gemini 生成的 JSON 中，\( 和 \) 在字符串值中未正確轉義
        // JSON 標準要求反斜線必須轉義，所以 \( 應該寫成 \\(
        // 問題：當遇到 \( 時，需要將整個序列轉義為 \\(
        try {
          debugPrint("   🔧 開始修復 LaTeX 轉義問題...");
          final beforeText = text;

          // 使用正則匹配所有 JSON 字符串（包括引號）
          text = text.replaceAllMapped(RegExp(r'"(?:[^"\\]|\\.)*"'), (match) {
            String fullMatch = match.group(0)!;
            // 提取引號內的內容（不包括引號）
            String content = fullMatch.substring(1, fullMatch.length - 1);

            final originalContent = content;

            // 逐字符處理，正確轉義所有未轉義的反斜線序列
            // 在 JSON 中，只有標準轉義序列是合法的，其他都需要轉義反斜線
            StringBuffer result = StringBuffer();

            for (int i = 0; i < content.length; i++) {
              if (content[i] == '\\' && i + 1 < content.length) {
                final nextChar = content[i + 1];

                // 標準的 JSON 轉義序列，保持原樣（已經是正確的 JSON 轉義）
                // \", \\, \/, \b, \f, \n, \r, \t, \uXXXX
                if (nextChar == '"' || nextChar == '\\' || nextChar == '/') {
                  result.write(content[i]);
                  result.write(nextChar);
                  i++; // 跳過下一個字符
                }
                // 這幾個字元同時是 JSON 轉義（\n, \r, \t, \b, \f）與 LaTeX 指令開頭（\neq, \right 等）
                // 如果後面還有英文字母，視為 LaTeX 指令，必須將反斜線轉義為 \\ 才能在 JSON 中合法呈現
                else if (nextChar == 'b' ||
                    nextChar == 'f' ||
                    nextChar == 'n' ||
                    nextChar == 'r' ||
                    nextChar == 't') {
                  final bool looksLikeLatexCommand = (i + 2 < content.length) &&
                      RegExp(r'[a-zA-Z]').hasMatch(content[i + 2]);
                  if (looksLikeLatexCommand) {
                    // 例如：\right, \frac, \neq, \theta, \beta
                    // 轉為 \\right, \\frac, \\neq 等，避免被 jsonDecode 當成控制字元吃掉
                    result.write('\\\\');
                    result.write(nextChar);
                    i++; // 跳過下一個字符
                  } else {
                    // 真正的 JSON 轉義如 \n、\r、\t，保持原樣
                    result.write(content[i]);
                    result.write(nextChar);
                    i++; // 跳過下一個字符
                  }
                }
                // 處理 \uXXXX（Unicode 轉義序列）
                else if (nextChar == 'u' && i + 5 < content.length) {
                  result.write(content[i]); // 寫入反斜線
                  result.write(nextChar); // 寫入 'u'
                  i++; // 跳過 'u'
                  // 寫入接下來的 4 個十六進制字符
                  for (int j = 0; j < 4 && i + 1 < content.length; j++) {
                    i++;
                    result.write(content[i]);
                  }
                }
                // 所有其他反斜線序列（LaTeX 命令如 \sqrt, \frac, \(, \) 等）都需要轉義反斜線
                else {
                  // 轉義反斜線：\sqrt → \\sqrt, \( → \\(
                  result.write('\\\\');
                  result.write(nextChar);
                  i++; // 跳過下一個字符
                }
              } else if (content[i] == '\\') {
                // 反斜線在字符串末尾，轉義它
                result.write('\\\\');
              } else {
                // 普通字符
                result.write(content[i]);
              }
            }

            final fixedContent = result.toString();
            if (originalContent != fixedContent) {
              debugPrint(
                  "   🔧 修復了字符串片段: ${originalContent.substring(0, math.min(80, originalContent.length))}...");
              debugPrint(
                  "   🔧 修復後: ${fixedContent.substring(0, math.min(80, fixedContent.length))}...");
            }

            return '"$fixedContent"';
          });

          if (beforeText != text) {
            debugPrint("   🔧 已修復 LaTeX 轉義問題（文本已改變）");
          } else {
            debugPrint("   ⚠️ 警告：修復後文本未改變，可能沒有匹配到需要修復的字符串");
          }
        } catch (e) {
          debugPrint("   ⚠️ 修復 LaTeX 轉義時出錯: $e，繼續嘗試解析原始 JSON");
        }

        // 🔍 添加：打印清理後的完整 JSON（或者至少包含 subject 的部分）
        debugPrint(
            "📥 清理後的 JSON 文字 (前500字): ${text.substring(0, math.min(500, text.length))}...");

        // 🔍 添加：嘗試查找 subject 字段
        final subjectMatch =
            RegExp(r'"subject"\s*:\s*"([^"]*)"').firstMatch(text);
        if (subjectMatch != null) {
          debugPrint(
              "   🔍 在 JSON 中找到 subject 字段: \"${subjectMatch.group(1)}\"");
        } else {
          debugPrint("   ⚠️ 警告：在 JSON 中未找到 subject 字段！");
          // 嘗試查找其他可能的格式
          final subjectMatch2 =
              RegExp(r'"subject"\s*:\s*([^,}\n]+)').firstMatch(text);
          if (subjectMatch2 != null) {
            debugPrint(
                "   🔍 找到 subject 字段（可能格式不同）: ${subjectMatch2.group(1)}");
          }
        }

        try {
          final result = jsonDecode(text) as Map<String, dynamic>;
          debugPrint("✅ JSON 解析成功");

          // 🔍 添加：打印解析後的 subject 值
          debugPrint("   🔍 解析後的 JSON keys: ${result.keys.toList()}");
          if (result.containsKey('subject')) {
            final parsedSubject = result['subject'];
            debugPrint(
                "   🔍 解析後的 subject 值: \"$parsedSubject\" (類型: ${parsedSubject.runtimeType})");
            if (parsedSubject == null ||
                parsedSubject.toString().isEmpty ||
                parsedSubject.toString() == 'null') {
              debugPrint("   ⚠️ 警告：subject 值為 null、空或字符串 'null'！");
            }
          } else {
            debugPrint("   ⚠️ 警告：解析後的 JSON 中沒有 subject 鍵！");
          }

          // ================================================
          // 根據 OCR 題目語言結構，最終修正 subject（英文/非英文）
          // 純英文 → 一定是英文科；純中文 → 一定不是英文科
          // ================================================
          try {
            final hasChinese =
                RegExp(r'[\u4e00-\u9fff]').hasMatch(normalizedQuestionText);
            final hasEnglish =
                RegExp(r'[A-Za-z]').hasMatch(normalizedQuestionText);
            final currentSubject = (result['subject'] ?? '').toString();

            if (hasEnglish && !hasChinese) {
              if (currentSubject != '英文') {
                debugPrint(
                    "   🔧 語言檢查：題目為純英文，強制將 subject 從 \"$currentSubject\" 更正為 \"英文\"");
              }
              result['subject'] = '英文';
            } else if (hasChinese &&
                !hasEnglish &&
                (currentSubject == '英文' || currentSubject == 'English')) {
              debugPrint(
                  "   🔧 語言檢查：題目為純中文，但 subject 為 \"$currentSubject\"，改為 \"不確定\"");
              result['subject'] = '不確定';
            }
          } catch (e) {
            debugPrint("   ⚠️ 語言結構檢查時發生例外：$e（略過修正，保留原 subject）");
          }

          return await _finalizeSolveResult(
            parsedResult: result,
            questionText: normalizedQuestionText,
            looksLikeMath: looksLikeMath,
            imageBytes: bytesForMultimodal,
            selectedModelName: selectedModelName,
          );
        } catch (e) {
          debugPrint("❌ JSON 解析失敗: $e");
          debugPrint(
              "   原始內容 (前200字): ${text.substring(0, math.min(200, text.length))}...");
          // 不再直接回傳原始回應，避免 prompt 或系統規則被帶到前台/列印內容。
          return _buildSafeFallbackResult(
            text,
            questionText: normalizedQuestionText,
          );
        }
      } else {
        // 回應為空，檢查原因
        debugPrint("❌ Gemini API 回應為空");

        if (response.candidates.isNotEmpty) {
          final candidate = response.candidates.first;
          debugPrint("   候選數量: ${response.candidates.length}");
          debugPrint("   完成原因 (finishReason): ${candidate.finishReason}");
          debugPrint(
              "   完成原因說明: ${_getFinishReasonDescription(candidate.finishReason)}");

          if (candidate.safetyRatings != null &&
              candidate.safetyRatings!.isNotEmpty) {
            debugPrint("   安全評級數量: ${candidate.safetyRatings!.length}");
            for (var rating in candidate.safetyRatings!) {
              debugPrint("     - ${rating.category}: ${rating.probability}");
            }
          }

          // 如果有 finishReason，可能是被安全過濾器阻擋
          if (candidate.finishReason == FinishReason.safety) {
            debugPrint("   ⚠️ 內容被安全過濾器阻擋");
          } else if (candidate.finishReason == FinishReason.recitation) {
            debugPrint("   ⚠️ 內容可能涉及版權問題");
          } else if (candidate.finishReason == FinishReason.maxTokens) {
            debugPrint("   ⚠️ 回應超過最大長度限制");
          } else if (candidate.finishReason == FinishReason.other) {
            debugPrint("   ⚠️ 其他原因導致回應為空");
          }
        } else {
          debugPrint("   ⚠️ 沒有任何候選回應");
        }

        return null;
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Gemini API 錯誤: $e");
      debugPrint("   錯誤類型: ${e.runtimeType}");

      final errorString = e.toString().toLowerCase();
      final errorMessage = e.toString();

      // 如果是模型不存在錯誤，嘗試備用模型
      if (errorString.contains("not found") ||
          errorString.contains("not_found") ||
          errorMessage.contains("models/gemini")) {
        final selectedModelName = _resolveSolveModelName(
          hasImage: bytesForMultimodal != null,
          looksLikeMath: looksLikeMath,
          looksLikeGeometry: looksLikeGeometry,
        );
        debugPrint("   💡 當前模型 '$selectedModelName' 不可用，嘗試備用模型...");

        // 備用模型列表
        final fallbackModels = <String>[
          if (_currentModelName.isNotEmpty) _currentModelName,
          _defaultModel,
          'gemini-1.5-flash',
          'gemini-1.5-flash-latest',
          'gemini-1.5-pro',
          'gemini-pro',
          'gemini-1.0-pro',
        ];

        for (final modelName in fallbackModels) {
          if (modelName == selectedModelName) continue; // 跳過已失敗模型

          try {
            debugPrint("   嘗試備用模型: $modelName");
            final fallbackModel = _createModel(modelName);

            // 備用模型也使用相同的內容格式
            final List<Content> fallbackContent;
            if (bytesForMultimodal != null) {
              fallbackContent = [
                Content.multi([
                  TextPart(prompt),
                  DataPart('image/jpeg', bytesForMultimodal),
                ])
              ];
            } else {
              fallbackContent = [Content.text(prompt)];
            }
            final response = await fallbackModel.generateContent(fallbackContent);

            if (response.text != null && response.text!.isNotEmpty) {
              debugPrint("   ✅ 備用模型 $modelName 成功！");
              if (modelName == _currentModelName || modelName == _defaultModel) {
                _model = fallbackModel;
                _currentModelName = modelName;
              }

              // 解析結果
              String text = response.text!;
              if (text.contains('```')) {
                text = text.replaceAll(RegExp(r'```json\n?'), '');
                text = text.replaceAll('```', '');
              }
              text = text.trim();

              try {
                return await _finalizeSolveResult(
                  parsedResult: jsonDecode(text) as Map<String, dynamic>,
                  questionText: questionText,
                  looksLikeMath: looksLikeMath,
                  imageBytes: bytesForMultimodal,
                  selectedModelName: modelName,
                );
              } catch (_) {
                return _buildSafeFallbackResult(text,
                    questionText: questionText);
              }
            }
          } catch (fallbackError) {
            debugPrint("   ❌ 備用模型 $modelName 也失敗: $fallbackError");
            continue;
          }
        }

        debugPrint("   ❌ 所有備用模型都失敗");
      }

      // 提供更具體的錯誤訊息
      String errorDetail = "未知錯誤";

      if (errorString.contains("api_key") ||
          errorString.contains("invalid api key") ||
          errorString.contains("invalid api")) {
        errorDetail = "API Key 無效或未設定";
      } else if (errorString.contains("permission") ||
          errorString.contains("forbidden") ||
          errorString.contains("403")) {
        errorDetail = "API Key 權限不足或被拒絕 (403)";
      } else if (errorString.contains("not found") ||
          errorString.contains("not_found") ||
          errorMessage.contains("models/gemini")) {
        errorDetail = "所有模型都不可用 - 請確認 API Key 有效或啟用計費";
        debugPrint("   💡 解決方案:");
        debugPrint("   1. 前往 https://makersuite.google.com/app/apikey");
        debugPrint("   2. 點擊 'Activate billing' 啟用計費");
        debugPrint("   3. 或創建新的 API Key");
      } else if (errorString.contains("network") ||
          errorString.contains("timeout") ||
          errorString.contains("connection") ||
          errorString.contains("socket")) {
        errorDetail = "網絡連接失敗，請檢查網絡連線";
      } else if (errorString.contains("quota") ||
          errorString.contains("rate limit") ||
          errorString.contains("429")) {
        errorDetail = "API 配額已用完或達到速率限制";
      } else if (errorString.contains("safety") ||
          errorString.contains("blocked")) {
        errorDetail = "內容被安全過濾器阻擋";
      }

      debugPrint("   錯誤詳情: $errorDetail");
      debugPrint("   堆疊追蹤 (前3行):");
      final stackLines = stackTrace.toString().split('\n');
      for (int i = 0; i < math.min(3, stackLines.length); i++) {
        debugPrint("     ${stackLines[i]}");
      }

      return null;
    }
  }

  /// 依據錯題生成一題不需要圖片的相似練習題。
  Future<Map<String, dynamic>?> generateSimilarPracticeQuestion({
    required String sourceQuestionText,
    File? imageFile,
  }) async {
    _lastSimilarPracticeError = null;
    final normalizedSourceQuestionText = LatexHelper.normalizeModelText(
      sourceQuestionText,
      preserveLineBreaks: true,
    );
    if (normalizedSourceQuestionText.isEmpty) {
      _lastSimilarPracticeError = '來源題目為空';
      return null;
    }

    if (!isReady) {
      try {
        await init();
        if (!isReady) {
          _lastSimilarPracticeError = _lastError ?? 'Gemini 尚未初始化';
          return null;
        }
      } catch (_) {
        _lastSimilarPracticeError = _lastError ?? 'Gemini 初始化失敗';
        return null;
      }
    }

    Uint8List? imageBytes;
    if (imageFile != null && await imageFile.exists()) {
      try {
        imageBytes = await imageFile.readAsBytes();
      } catch (_) {
        imageBytes = null;
      }
    }

    Map<String, dynamic>? sourceAnalysis;
    try {
      sourceAnalysis = await solveProblem(
        normalizedSourceQuestionText,
        imageFile: imageFile,
      );
    } catch (_) {
      sourceAnalysis = null;
    }

    final detectedSubject = sourceAnalysis?['subject']?.toString().trim();
    final detectedCategory = sourceAnalysis?['category']?.toString().trim();
    final detectedGradeLevel =
        sourceAnalysis?['grade_level']?.toString().trim();
    final detectedChapter = sourceAnalysis?['chapter']?.toString().trim();
    final detectedKeyConcepts =
        _normalizeStringList(sourceAnalysis?['key_concepts']);

    final imageInstruction = imageBytes == null
        ? ''
        : '''
你同時會看到原題圖片。圖片只用來幫助你理解原題，不可要求新題依賴任何新圖片、圖表、表格或幾何圖形才能作答。
若原題本身依賴圖片，請改寫成同觀念、可用純文字或 LaTeX 完整表達的新題。
''';

    final sourceContext = '''
若下列來源分析可用，請優先沿用：
- 科目：${detectedSubject?.isNotEmpty == true ? detectedSubject : '待判斷'}
- 題型分類：${detectedCategory?.isNotEmpty == true ? detectedCategory : '待判斷'}
- 年級：${detectedGradeLevel?.isNotEmpty == true ? detectedGradeLevel : '待判斷'}
- 章節：${detectedChapter?.isNotEmpty == true ? detectedChapter : '待判斷'}
- 核心觀念：${detectedKeyConcepts.isEmpty ? '待判斷' : detectedKeyConcepts.join('、')}
''';

    final gradeStrategy =
        _buildSimilarPracticeGradeStrategy(detectedGradeLevel);
    final subjectStrategy =
        _buildSimilarPracticeSubjectStrategy(detectedSubject);

    final prompt = '''
你是一位熟悉台灣國中與高中題型的老師，特別擅長幫學生把錯題轉成有效練習。請根據使用者輸入的錯題，生成 1 題「相似但不是照抄」的新練習題。

$imageInstruction
$sourceContext
原始錯題如下：
「$normalizedSourceQuestionText」

$gradeStrategy
$subjectStrategy

請嚴格遵守以下規則：
1. 新題必須考相同或非常接近的核心觀念。
2. 新題必須可以只靠文字或 LaTeX 作答，不能依賴任何新圖片。
3. 不可要求參考圖、表、地圖、座標圖、幾何圖、實驗圖或閱讀附圖。
4. 若原題需要圖片，請主動改寫成等值的純文字版本。
5. 不可直接照抄原題數字、句子或選項，要保留觀念但換題目內容。
6. 請使用繁體中文。
7. explanation 要適合國中生閱讀，清楚、友善、可直接拿來複習。
8. 若來源是國中題，禁止跳到高中才會學的核心方法或術語。
9. 若無法判斷年級，預設以國中生可理解的難度出題。
10. 先在內部完成驗算，只輸出驗算後的最終版本，不可輸出嘗試、修正、反思、檢查過程或錯誤思路。
11. 若你發現題目條件不足、可能多解、可能無解，或無法確認答案唯一，請直接在內部重寫成條件完整、可解且答案明確的新題後再輸出。
12. question_text 不可出現「如下圖」、「參考附圖」、「看圖作答」、「表中資料」等需要額外素材的描述。
13. explanation 只能保留最終正確解法，不可出現「一開始算錯」、「再修正」、「最後修正」、「重新檢查後」這類文字。
14. answer 必須與 explanation 一致，且可以回推出 question_text 的唯一合理答案。
15. 只要有數學公式、算式、未知數、分數、根號、次方、下標、乘號或不等式，必須使用標準 LaTeX。
16. 行內公式一律使用 \\( ... \\)；獨立成行的公式一律使用 \\[ ... \\]。禁止直接在中文句子裡裸露輸出 x^2、a_n、\\frac、\\sqrt、\\times 這類公式片段。
17. 所有 LaTeX 指令前只能有一個反斜線，且所有括號 {}, (), [] 必須完整閉合。
18. 如果一句中文裡夾了算式，例如「面積為 x^2+3x」，請輸出成「面積為 \\( x^2 + 3x \\)」。

只輸出 JSON，不要輸出 Markdown，不要加上 ```json。

{
  "question_text": "新練習題題目（公式必須用標準 LaTeX 包裹）",
  "answer": "答案（若有公式必須用標準 LaTeX 包裹）",
  "explanation": "解析（若有公式必須用標準 LaTeX 包裹）",
  "difficulty": "same",
  "subject": "數學/英文/國文/自然/地理/歷史/公民/其他",
  "grade_level": "國一/國二/國三/高一/高二/高三/不確定",
  "category": "具體題型分類",
  "chapter": "具體章節名稱",
  "key_concepts": ["核心觀念1", "核心觀念2"],
  "key_point": "這題主要在練什麼觀念"
}

difficulty 只能是 same、easier、harder 其中一個。
key_concepts 請輸出 2 到 4 個具體概念。
''';

    // 相似題生成常見失敗原因是：模型多吐非 JSON 文字、JSON 字串跳脫不完整、或二次驗證格式回傳異常。
    // 這些多屬於「格式不穩」而非「模型不會出題」，因此用較高重試次數與更強的 JSON 抽取/修復可顯著提升成功率。
    const maxGenerationAttempts = 6;
    String? lastFailure;

    // 盡量強制模型輸出 JSON（降低格式型失敗）
    // 不修改全域 _model，避免影響其他功能
    final jsonPreferredModel = GenerativeModel(
      model: _currentModelName.isNotEmpty ? _currentModelName : _defaultModel,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.6,
      ),
    );

    for (var attempt = 1; attempt <= maxGenerationAttempts; attempt++) {
      try {
        final List<Content> contentList;
        if (imageBytes != null) {
          contentList = [
            Content.multi([
              TextPart(prompt),
              DataPart('image/jpeg', imageBytes),
            ])
          ];
        } else {
          contentList = [Content.text(prompt)];
        }

        final response = await jsonPreferredModel
            .generateContent(contentList)
            .timeout(const Duration(seconds: 60));
        final rawText = response.text;
        if (rawText == null || rawText.trim().isEmpty) {
          debugPrint("⚠️ 相似題第 $attempt 次生成為空");
          lastFailure = 'AI 回傳空內容';
          continue;
        }

        var cleaned = _normalizeAiText(rawText);
        cleaned = _repairJsonStringBackslashes(cleaned);
        cleaned = _extractFirstJsonObject(cleaned) ?? cleaned;
        cleaned = _sanitizeJsonTextForDecode(cleaned);

        dynamic decoded;
        try {
          decoded = jsonDecode(cleaned);
        } catch (e) {
          // 再做一次更激進的容錯修復（常見於字串內含未跳脫換行、智慧引號、尾逗號等）
          final aggressive = _sanitizeJsonTextForDecode(cleaned, aggressive: true);
          try {
            decoded = jsonDecode(aggressive);
            cleaned = aggressive;
          } catch (e2) {
            debugPrint("⚠️ 相似題第 $attempt 次 JSON 解析失敗: $e2");
            lastFailure = 'AI 回傳不是合法 JSON';
            continue;
          }
        }
        if (decoded is! Map<String, dynamic>) {
          debugPrint("⚠️ 相似題第 $attempt 次格式不是 JSON 物件");
          lastFailure = 'AI 回傳不是 JSON 物件';
          continue;
        }

        final questionText = decoded['question_text']?.toString().trim() ?? '';
        final answer = decoded['answer']?.toString().trim() ?? '';
        final explanation = decoded['explanation']?.toString().trim() ?? '';
        final difficulty = decoded['difficulty']?.toString().trim() ?? 'same';
        final subject = decoded['subject']?.toString().trim() ?? '';
        final gradeLevel = decoded['grade_level']?.toString().trim() ?? '';
        final category = decoded['category']?.toString().trim() ?? '';
        final chapter = decoded['chapter']?.toString().trim() ?? '';
        final keyConceptsRaw = _normalizeStringList(decoded['key_concepts']);
        final keyPoint = decoded['key_point']?.toString().trim() ?? '';

        if (questionText.isEmpty || answer.isEmpty || explanation.isEmpty) {
          debugPrint("⚠️ 相似題第 $attempt 次缺少必要欄位");
          lastFailure = 'AI 回傳缺少必要欄位（題目/答案/解析）';
          continue;
        }

        if (_containsExternalReference(questionText) ||
            _containsExternalReference(explanation) ||
            _looksLikeDraftReasoning(explanation)) {
          debugPrint("⚠️ 相似題第 $attempt 次含草稿痕跡或外部參照");
          lastFailure = 'AI 內容出現外部參照或草稿語氣';
          continue;
        }

        final chapterCombined = chapter.isNotEmpty
            ? _normalizeAiText(chapter)
            : (detectedChapter?.isNotEmpty == true ? detectedChapter! : '');
        final chapterForResult =
            Mistake.normalizeChapterForStorage(chapterCombined) ?? '';

        final conceptsMerged = keyConceptsRaw.isNotEmpty
            ? keyConceptsRaw.map(_normalizeAiText).toList()
            : detectedKeyConcepts.map(_normalizeAiText).toList();
        final conceptsForResult =
            Mistake.normalizeTagsForStorage(conceptsMerged);

        final candidateResult = {
          'question_text': _stripRedundantTrailingFigureNote(
            _normalizeAiText(questionText),
          ),
          'answer': _normalizeAiText(answer),
          'explanation': _normalizeAiText(explanation),
          'difficulty': const {'same', 'easier', 'harder'}.contains(difficulty)
              ? difficulty
              : 'same',
          'subject': subject.isNotEmpty
              ? _normalizeAiText(subject)
              : (detectedSubject?.isNotEmpty == true ? detectedSubject : '其他'),
          'grade_level': gradeLevel.isNotEmpty
              ? _normalizeAiText(gradeLevel)
              : (detectedGradeLevel ?? '不確定'),
          'category': category.isNotEmpty
              ? _normalizeAiText(category)
              : (detectedCategory?.isNotEmpty == true
                  ? detectedCategory
                  : '其他'),
          'chapter': chapterForResult,
          'key_concepts': conceptsForResult,
          'key_point': _normalizeAiText(
            keyPoint.isNotEmpty
                ? keyPoint
                : (conceptsForResult.isNotEmpty
                    ? conceptsForResult.first
                    : '核心概念待確認'),
          ),
        };

        final isValidated = await _validateSimilarPracticeWithAi(
          sourceQuestionText: normalizedSourceQuestionText,
          candidateResult: candidateResult,
        );
        if (!isValidated) {
          debugPrint("⚠️ 相似題第 $attempt 次未通過二次驗證，將重試生成");
          lastFailure = '題目品質審核未通過';
          continue;
        }

        return candidateResult;
      } catch (e) {
        debugPrint("❌ 相似題第 $attempt 次生成失敗: $e");
        lastFailure = '生成時發生例外：$e';
      }
    }

    _lastSimilarPracticeError = lastFailure ?? '未知原因（多次重試仍失敗）';
    return null;
  }

  Future<String?> askTutorFollowUp({
    required String questionText,
    required String studentQuestion,
    String? subject,
    String? category,
    String? chapter,
    List<String> keyConcepts = const [],
    List<Map<String, String>> solutions = const [],
    List<Map<String, String>> history = const [],
  }) async {
    if (!isReady) {
      try {
        await init();
        if (!isReady) return null;
      } catch (_) {
        return null;
      }
    }

    final normalizedQuestionText = LatexHelper.normalizeModelText(
      questionText,
      preserveLineBreaks: true,
    );
    final trimmedStudentQuestion = LatexHelper.normalizeModelText(
      studentQuestion,
      preserveLineBreaks: true,
    );
    if (trimmedStudentQuestion.isEmpty) return null;

    final historyText = history.isEmpty
        ? '無'
        : history.map((item) {
            final role = item['role'] == 'user' ? '學生' : '老師';
            final content = _normalizeAiText(item['content']?.toString() ?? '');
            return '$role：$content';
          }).join('\n');

    final solutionsText = solutions.isEmpty
        ? '目前沒有現成解法可參考'
        : solutions.map((item) {
            final title =
                _normalizeAiText(item['title']?.toString() ?? '').isNotEmpty
                    ? _normalizeAiText(item['title']?.toString() ?? '')
                    : '解法';
            final content = _normalizeAiText(item['content']?.toString() ?? '');
            return '$title：$content';
          }).join('\n\n');

    final prompt = '''
你是一位很會教學生的家教老師。請根據題目、已知解析與對話脈絡，回答學生的追問。

請遵守以下規則：
1. 一律使用繁體中文。
2. 先直接回答學生真正卡住的點，不要重複整題完整解析。
3. 優先用國中/高中學生能懂的語氣，簡單、具體、友善。
4. 若需要公式，保留簡潔的 LaTeX 或數學符號即可。
5. 若學生在問「為什麼這一步可以這樣做」，請聚焦解釋原理。
6. 若學生在問「有沒有更快的方法」，請提供較短的替代思路。
7. 若學生在問練習方向，可以給 1 個很短的小練習提示，但不要離題。
8. 不要捏造看不到的圖形細節；若題目需要圖形，請明講你只能依現有文字與解析回答。
9. 回答盡量控制在 3 到 8 句，除非學生要求更詳細。

【題目】
$normalizedQuestionText

【題目資訊】
- 科目：${subject?.trim().isNotEmpty == true ? subject!.trim() : '未提供'}
- 類別：${category?.trim().isNotEmpty == true ? category!.trim() : '未提供'}
- 章節：${chapter?.trim().isNotEmpty == true ? chapter!.trim() : '未提供'}
- 核心觀念：${keyConcepts.isEmpty ? '未提供' : keyConcepts.join('、')}

【已知解析】
$solutionsText

【先前對話】
$historyText

【學生這次的問題】
$trimmedStudentQuestion

請直接輸出老師要對學生說的內容，不要輸出 JSON，不要加標題。
''';

    try {
      final response = await _model!.generateContent(
          [Content.text(prompt)]).timeout(const Duration(seconds: 60));
      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        return null;
      }
      return _normalizeAiText(text);
    } catch (e) {
      debugPrint('❌ AI 互動問答失敗: $e');
      return null;
    }
  }

  Future<String?> inferSolutionFromCorrectAnswer({
    required String questionText,
    required String correctAnswer,
    String? subject,
    String? category,
    String? chapter,
    List<String> keyConcepts = const [],
    List<Map<String, String>> solutions = const [],
    List<Map<String, String>> history = const [],
  }) async {
    if (!isReady) {
      try {
        await init();
        if (!isReady) return null;
      } catch (_) {
        return null;
      }
    }

    final normalizedQuestionText = LatexHelper.normalizeModelText(
      questionText,
      preserveLineBreaks: true,
    );
    final normalizedCorrectAnswer = LatexHelper.normalizeModelText(
      correctAnswer,
      preserveLineBreaks: true,
    );
    if (normalizedCorrectAnswer.isEmpty) return null;

    final historyText = history.isEmpty
        ? '無'
        : history.map((item) {
            final role = item['role'] == 'user' ? '學生' : '老師';
            final content = _normalizeAiText(item['content']?.toString() ?? '');
            return '$role：$content';
          }).join('\n');

    final solutionsText = solutions.isEmpty
        ? '目前沒有可參考的既有解析'
        : solutions.map((item) {
            final title =
                _normalizeAiText(item['title']?.toString() ?? '').isNotEmpty
                    ? _normalizeAiText(item['title']?.toString() ?? '')
                    : '解法';
            final content = _normalizeAiText(item['content']?.toString() ?? '');
            return '$title：$content';
          }).join('\n\n');

    final prompt = '''
你是一位非常保守、重視誠實的家教老師。先前 AI 對這題的解析可能做錯了，現在學生提供了他確認的正確答案。

請嚴格遵守以下規則：
1. 一律使用繁體中文。
2. 你只能根據「題目文字」「既有對話」「可能有誤的舊解析」以及「學生提供的正確答案」來保守推斷可能解法。
3. 絕對不可捏造圖形細節、隱含條件、未提供的數值、選項內容或任何你無法從現有資訊確認的內容。
4. 如果目前資訊不足，無法可靠推出完整解法，請直接明說你不知道，或說你無法可靠推斷，不要硬編。
5. 如果你能提出推斷，開頭第一句必須明確說：
   「以下是根據你提供的正確答案倒推出來的可能解法，不一定是原題唯一思路，請謹慎使用。」
6. 如果題目條件不足、可能多解、需要看圖、或缺少關鍵選項/圖形資訊，也必須誠實講清楚。
7. 不要試圖合理化原本錯誤的 AI 解法；若舊解析與正確答案衝突，請直接以學生提供的正確答案為主，並指出舊解析可能有誤。
8. 回答盡量控制在 4 到 8 句；若真的無法推斷，簡短清楚說明原因即可。
9. 若需要公式，可使用簡潔 LaTeX，但不要過度延伸。
10. 請把輸出寫成可直接收藏到錯題本的說明文字，不要使用條列、標題、Markdown、編號或多層結構。
11. 若無法可靠推斷，請優先用這種語氣開頭：「我目前無法只根據你提供的正確答案，可靠地倒推出完整解法。」
12. 若可以保守推斷，請在開頭保留風險提醒，但後面仍要盡量提供可複習的思路，不要只重複警語。
13. 若你判斷錯誤很可能來自題目辨識（例如 OCR 缺字、亂碼、選項不完整、題幹被裁切、明顯讀錯符號），請在回答中溫和建議學生可嘗試重新拍攝或重新框選較清晰、完整的題目區域後再解析一次；不要當成一般計算錯誤硬推解法。

【題目】
$normalizedQuestionText

【題目資訊】
- 科目：${subject?.trim().isNotEmpty == true ? subject!.trim() : '未提供'}
- 類別：${category?.trim().isNotEmpty == true ? category!.trim() : '未提供'}
- 章節：${chapter?.trim().isNotEmpty == true ? chapter!.trim() : '未提供'}
- 核心觀念：${keyConcepts.isEmpty ? '未提供' : keyConcepts.join('、')}

【舊的 AI 解析（可能有誤，不能直接相信）】
$solutionsText

【先前對話】
$historyText

【學生確認的正確答案】
$normalizedCorrectAnswer

請直接輸出你要對學生說的內容，不要輸出 JSON，不要加標題。
''';

    try {
      final response = await _model!
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 60));
      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        return null;
      }
      return _normalizeAiText(text);
    } catch (e) {
      debugPrint('❌ 依正確答案保守推斷解法失敗: $e');
      return null;
    }
  }

  Map<String, dynamic> _sanitizeParsedResult(
    Map<String, dynamic> result, {
    required String questionText,
  }) {
    final sanitized = Map<String, dynamic>.from(result);
    final sanitizedSolutions = _sanitizeSolutions(
      result['solutions'],
      questionText: questionText,
    );

    if (sanitizedSolutions.isEmpty) {
      sanitized.remove('solutions');
    } else {
      sanitized['solutions'] = sanitizedSolutions;
    }

    final normalizedQuestionText = _stripRedundantTrailingFigureNote(
      _normalizeAiText(
        result['question_text']?.toString() ?? questionText,
      ),
    );
    if (normalizedQuestionText.isNotEmpty) {
      sanitized['question_text'] = normalizedQuestionText;
    }

    for (final field in [
      'subject',
      'grade_level',
      'category',
      'chapter',
      'answer',
      'key_point',
    ]) {
      final normalized = _normalizeAiText(result[field]?.toString() ?? '');
      if (normalized.isNotEmpty) {
        sanitized[field] = normalized;
      } else {
        sanitized.remove(field);
      }
    }

    final normalizedConcepts = _normalizeStringList(result['key_concepts']);
    if (normalizedConcepts.isEmpty) {
      sanitized.remove('key_concepts');
    } else {
      sanitized['key_concepts'] = normalizedConcepts;
    }

    return sanitized;
  }

  List<Map<String, String>> _sanitizeSolutions(
    dynamic rawSolutions, {
    required String questionText,
  }) {
    if (rawSolutions is! List) return const [];

    final seen = <String>{};
    final sanitized = <Map<String, String>>[];

    for (final item in rawSolutions) {
      String title = '解法';
      String content = '';

      if (item is Map<String, dynamic>) {
        title = item['title']?.toString().trim().isNotEmpty == true
            ? item['title'].toString().trim()
            : '解法';
        content = item['content']?.toString() ?? '';
      } else if (item != null) {
        content = item.toString();
      }

      content = _normalizeAiText(content);
      if (content.isEmpty) continue;
      if (_containsPromptArtifacts(content, questionText: questionText)) {
        continue;
      }
      if (!seen.add('$title\n$content')) continue;

      sanitized.add({
        'title':
            _normalizeAiText(title).isEmpty ? '解法' : _normalizeAiText(title),
        'content': content,
      });
    }

    return sanitized;
  }

  bool _shouldRunSolveValidation({
    required bool hasImage,
    required bool looksLikeMath,
  }) {
    final enabled =
        AppEnvironment.geminiSolveValidateMathWithImage == '1';
    return enabled && hasImage && looksLikeMath;
  }

  String _resolveSolveValidationModelName(String preferredSolveModelName) {
    final configured = AppEnvironment.geminiSolveValidationModel;
    if (configured.isNotEmpty) return configured;
    return preferredSolveModelName;
  }

  Future<Map<String, dynamic>> _finalizeSolveResult({
    required Map<String, dynamic> parsedResult,
    required String questionText,
    required bool looksLikeMath,
    required Uint8List? imageBytes,
    required String selectedModelName,
  }) async {
    final sanitized = _sanitizeParsedResult(
      parsedResult,
      questionText: questionText,
    );

    if (!_shouldRunSolveValidation(
      hasImage: imageBytes != null,
      looksLikeMath: looksLikeMath,
    )) {
      return sanitized;
    }

    final validation = await _validateSolveResultWithAi(
      sourceQuestionText: questionText,
      candidateResult: sanitized,
      imageBytes: imageBytes,
      modelName: _resolveSolveValidationModelName(selectedModelName),
    );
    final isValid = validation['is_valid'] == true;
    final reason = validation['reason']?.toString().trim() ?? '';
    debugPrint('🔎 解題二次驗證結果: is_valid=$isValid, reason=$reason');
    if (isValid) return sanitized;

    return _buildSolveValidationWarningResult(
      sanitized,
      questionText: questionText,
      reason: reason,
    );
  }

  Map<String, dynamic> _buildSolveValidationWarningResult(
    Map<String, dynamic> baseResult, {
    required String questionText,
    required String reason,
  }) {
    final safe = Map<String, dynamic>.from(baseResult);
    final cleanedReason = _normalizeAiText(reason);
    final reminder =
        '本題圖文一致性檢查未通過${cleanedReason.isNotEmpty ? '：$cleanedReason' : ''}。請重新解析一次，並確認裁切有包含完整圖形、標示與選項。';

    final normalizedQuestionText = _stripRedundantTrailingFigureNote(
      _normalizeAiText(safe['question_text']?.toString() ?? questionText),
    );
    if (normalizedQuestionText.isNotEmpty) {
      safe['question_text'] = normalizedQuestionText;
    }
    safe['solutions'] = [
      {'title': '附圖驗證未通過', 'content': reminder}
    ];
    return safe;
  }

  Map<String, dynamic> _buildSafeFallbackResult(
    String rawText, {
    required String questionText,
  }) {
    final cleaned = _normalizeAiText(rawText);
    if (cleaned.isNotEmpty &&
        cleaned.length <= 1200 &&
        !_containsPromptArtifacts(cleaned, questionText: questionText)) {
      return {
        'solutions': [
          {'title': 'AI 解析', 'content': cleaned}
        ]
      };
    }

    return {
      'solutions': [
        {'title': 'AI 解析失敗', 'content': '本次 AI 回應格式異常，已略過不安全內容，請重新解析一次。'}
      ]
    };
  }

  /// 模型或前處理可能在句尾留下「（如圖）」；與 [LatexHelper.stripEditorialFigurePhrases] 同步清理。
  String _stripRedundantTrailingFigureNote(String text) {
    return LatexHelper.stripEditorialFigurePhrases(text);
  }

  /// 解題前尚無 Gemini 回傳的 subject；用 OCR 字串做保守的「數學題」判斷，供
  /// [GEMINI_SOLVE_ALWAYS_ATTACH_IMAGE_FOR_MATH] 僅對數學強制附圖。
  bool _ocrLooksLikeMath(String t) {
    final s = t.trim();
    if (s.isEmpty) return false;
    if (RegExp(r'[√∑∫π∠△∥⊥∽≌°²³ⁿ⁴⁵⁶⁷⁸⁹⁰±×÷≤≥≠≈∞∈∂∇]').hasMatch(s)) {
      return true;
    }
    if (RegExp(
            r'\\frac|\\sqrt|\\begin|\\end|\\mathrm|\\times|\\div|\\pm|\\leq|\\geq|\\neq|\\approx|\\pi|\\sum|\\int|\\Delta|\\angle|\\parallel|\\perp|\\sim|\\cong|\\circ|\\ldots|\\cdots|\\infty|\\cdot|\\left|\\right')
        .hasMatch(s)) {
      return true;
    }
    if (s.contains(r'$$') || RegExp(r'\$[^$\n]{1,1200}\$').hasMatch(s)) {
      return true;
    }
    if (RegExp(
            r'因式分解|化簡|展開式|一元二次|二次函數|三角函數|對數|指數函數|根號|次方|平方根|立方根|相似三角形|三角形相似|全等|勾股|畢氏定理|向量\b|坐標\b|座標\b|直角坐標|斜率|微分|積分|機率\b|期望值|排列組合|等差數列|等比數列|矩陣|行列式|解方程式|不等式\b|面積|體積|周長|半徑|直徑|弧長|弧度|圓周角|圓心角|正弦|餘弦|正切|f\(\s*x\s*\)')
        .hasMatch(s)) {
      return true;
    }
    return false;
  }

  bool _ocrLooksLikeGeometryMath(String t) {
    final s = t.trim();
    if (s.isEmpty || !_ocrLooksLikeMath(s)) return false;

    return RegExp(
      r'幾何|平面幾何|立體幾何|三角形|四邊形|多邊形|相似|全等|勾股|畢氏定理|圓周角|圓心角|弧長|弧度|弧|弦|切線|割線|半徑|直徑|周長|面積|體積|夾角|角度|垂直|平行|中垂線|角平分線|高線|中線|外心|內心|重心|垂心|扇形|圓錐|圓柱|球體|展開圖|俯視圖|前視圖|側視圖|線段|射線|直線|梯形|菱形|平行四邊形|正方形|長方形|切點|交點|頂點|對角線|陰影部分|\\angle|\\triangle|\\overline|\\parallel|\\perp|\\cong|\\sim',
    ).hasMatch(s);
  }

  /// 命中這些關鍵字時，代表題目很可能仍需看圖，不應僅因選項完整就略過附圖。
  bool _containsMustAttachImageSignals(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;

    return RegExp(
      r'如圖|見圖|附圖|圖形|圖\(|坐標|座標|數線|函數圖|統計圖|折線圖|長條圖|圓形圖|地圖|示意圖|幾何|平面幾何|立體幾何|相似|全等|三角形|四邊形|多邊形|圓周角|圓心角|弧長|弧度|弧|弦|切線|割線|半徑|直徑|周長|面積|體積|夾角|角度|垂直|平行|中垂線|角平分線|高線|中線|外心|內心|重心|垂心|扇形|圓錐|圓柱|球體|展開圖|俯視圖|前視圖|側視圖|座標平面|直角坐標|線段|射線|直線|梯形|菱形|平行四邊形|正方形|長方形|切點|交點|頂點|對角線|陰影部分',
    ).hasMatch(t);
  }

  /// 保守判斷：純文字＋選項已齊時略過附圖以節省 token（幾何／圖表關鍵字仍會附圖）。
  bool _shouldOmitProblemImageForTokenSavings(String ocr) {
    final t = ocr.trim();
    if (t.length < 48) return false;
    if (_containsMustAttachImageSignals(t)) {
      return false;
    }
    final labels =
        RegExp(r'[\(（]\s*[A-Da-dＡ-Ｄ]\s*[\)）]').allMatches(t).length;
    return labels >= 2;
  }

  String _normalizeAiText(String text) {
    return LatexHelper.normalizeModelText(text, preserveLineBreaks: true);
  }

  List<String> _normalizeStringList(dynamic rawList) {
    if (rawList is! List) return const [];
    return rawList
        .map((item) => _normalizeAiText(item.toString()))
        .where((item) => item.isNotEmpty)
        .toList();
  }

  bool _containsExternalReference(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return false;

    return RegExp(
      r'如下圖|參考附圖|參考下圖|看圖作答|由圖可知|圖中|表中資料|參考下表|附表|座標圖|幾何圖|實驗圖',
    ).hasMatch(normalized);
  }

  bool _looksLikeDraftReasoning(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return false;

    return RegExp(
      r'一開始算錯|前面算錯|再修正|最後修正|重新檢查後|重新計算後|改成|更正為|思路|推理過程|先假設|先試',
    ).hasMatch(normalized);
  }

  Future<bool> _validateSimilarPracticeWithAi({
    required String sourceQuestionText,
    required Map<String, dynamic> candidateResult,
  }) async {
    if (_model == null) return false;

    final prompt = '''
你是「題目品質審核員」。請審核下列 AI 相似題是否合格。

【來源題目】
$sourceQuestionText

【待審核相似題(JSON)】
${jsonEncode(candidateResult)}

請嚴格檢查以下條件，任一不符合都判定不合格：
1. 題目條件完整，且是可解題（不是資訊不足）。
2. 答案唯一且明確，不是多解或無解。
3. answer 與 explanation 一致，且 explanation 能合理推出 answer。
4. explanation 不包含錯誤嘗試、修正過程、反思稿或草稿語氣。
5. 題目不依賴附圖、表格、外部資訊，僅靠文字即可作答。

只輸出 JSON，不要任何額外文字：
{
  "is_valid": true 或 false,
  "reason": "一句話說明"
}
''';

    try {
      final response = await _model!
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 45));
      final rawText = response.text;
      if (rawText == null || rawText.trim().isEmpty) {
        debugPrint('⚠️ 相似題二次驗證回傳空內容');
        // 二次驗證回傳空屬於「不確定」，不應成為主要失敗來源：放行以提升成功率
        return true;
      }

      var cleaned = _normalizeAiText(rawText);
      cleaned = _repairJsonStringBackslashes(cleaned);
      cleaned = _extractFirstJsonObject(cleaned) ?? cleaned;
      cleaned = _sanitizeJsonTextForDecode(cleaned);

      final decoded = jsonDecode(cleaned);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('⚠️ 相似題二次驗證格式異常');
        // 二次驗證格式異常屬於「不確定」，放行以避免誤殺好題
        return true;
      }

      final isValid = decoded['is_valid'] == true;
      final reason = decoded['reason']?.toString().trim() ?? '';
      debugPrint('🔎 相似題二次驗證結果: is_valid=$isValid, reason=$reason');
      return isValid;
    } catch (e) {
      debugPrint('❌ 相似題二次驗證失敗: $e');
      // 二次驗證本身可能因格式/配額/偶發錯誤失敗；此時視為不確定，放行以提升成功率
      return true;
    }
  }

  Future<Map<String, dynamic>> _validateSolveResultWithAi({
    required String sourceQuestionText,
    required Map<String, dynamic> candidateResult,
    required String modelName,
    Uint8List? imageBytes,
  }) async {
    final validatorModel = GenerativeModel(
      model: modelName,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.1,
      ),
    );

    final prompt = '''
你是「數學附圖解題審核員」。請審核下列解題結果是否通過圖文一致性檢查。

【OCR 題目文字】
$sourceQuestionText

【待審核解題結果(JSON)】
${jsonEncode(candidateResult)}

請嚴格檢查以下條件，任一不符合都判定不合格：
1. 解法與最終結論不得忽略圖片中的關鍵條件、標示、角度、邊長、座標或圖形關係。
2. 若 OCR 與圖片衝突，解法不得混用兩邊資訊。
3. 不可自行腦補圖上未標示的相似、全等、平行、垂直、長度、角度或其他隱含條件。
4. 若是選擇題，解法推理與最後結論必須支持同一個選項。
5. 若依照 OCR 與圖片仍不足以唯一決定答案，應判定不合格。

若回應格式本身沒有足夠資訊判斷，也視為不合格。

只輸出 JSON，不要任何額外文字：
{
  "is_valid": true 或 false,
  "reason": "一句話說明"
}
''';

    try {
      final List<Content> contentList;
      if (imageBytes != null) {
        contentList = [
          Content.multi([
            TextPart(prompt),
            DataPart('image/jpeg', imageBytes),
          ])
        ];
      } else {
        contentList = [Content.text(prompt)];
      }

      final response = await validatorModel
          .generateContent(contentList)
          .timeout(const Duration(seconds: 45));
      final rawText = response.text;
      if (rawText == null || rawText.trim().isEmpty) {
        debugPrint('⚠️ 解題二次驗證回傳空內容');
        return {
          'is_valid': true,
          'reason': 'validator_empty',
        };
      }

      var cleaned = _normalizeAiText(rawText);
      cleaned = _repairJsonStringBackslashes(cleaned);
      cleaned = _extractFirstJsonObject(cleaned) ?? cleaned;
      cleaned = _sanitizeJsonTextForDecode(cleaned);

      final decoded = jsonDecode(cleaned);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('⚠️ 解題二次驗證格式異常');
        return {
          'is_valid': true,
          'reason': 'validator_format_uncertain',
        };
      }

      return {
        'is_valid': decoded['is_valid'] == true,
        'reason': decoded['reason']?.toString().trim() ?? '',
      };
    } catch (e) {
      debugPrint('❌ 解題二次驗證失敗: $e');
      return {
        'is_valid': true,
        'reason': 'validator_exception',
      };
    }
  }

  /// 從 AI 回應中抽取第一個 JSON 物件 `{ ... }`。
  /// 模型偶爾會在 JSON 前後加一句話，導致 jsonDecode 失敗；這裡做容錯抽取。
  /// 若抽取不到，回傳 null。
  String? _extractFirstJsonObject(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final first = trimmed.indexOf('{');
    if (first == -1) return null;

    int depth = 0;
    bool inString = false;
    bool escape = false;
    for (int i = first; i < trimmed.length; i++) {
      final ch = trimmed[i];

      if (inString) {
        if (escape) {
          escape = false;
          continue;
        }
        if (ch == r'\') {
          escape = true;
          continue;
        }
        if (ch == '"') {
          inString = false;
        }
        continue;
      }

      if (ch == '"') {
        inString = true;
        continue;
      }
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) {
          return trimmed.substring(first, i + 1);
        }
      }
    }
    return null;
  }

  /// 讓 JSON 更容易被 `jsonDecode` 接受的容錯修復：
  /// - 將字串內的未跳脫換行/Tab 轉成 `\\n` / `\\t`
  /// - 移除 JSON 外層多餘空白與不可見字元
  /// - （aggressive）修復智慧引號、移除尾逗號
  String _sanitizeJsonTextForDecode(
    String text, {
    bool aggressive = false,
  }) {
    var input = text.trim();
    if (input.isEmpty) return input;

    if (aggressive) {
      // 常見智慧引號 → 標準雙引號
      input = input
          .replaceAll('“', '"')
          .replaceAll('”', '"')
          .replaceAll('‘', "'")
          .replaceAll('’', "'");
    }

    final buffer = StringBuffer();
    bool inString = false;
    bool escape = false;

    for (int i = 0; i < input.length; i++) {
      final ch = input[i];

      if (inString) {
        if (escape) {
          // 先寫入被跳脫字元
          buffer.write(ch);
          escape = false;
          continue;
        }

        if (ch == r'\') {
          buffer.write(ch);
          escape = true;
          continue;
        }

        // JSON 字串內不允許裸 \n \r \t
        if (ch == '\n') {
          buffer.write(r'\n');
          continue;
        }
        if (ch == '\r') {
          buffer.write(r'\r');
          continue;
        }
        if (ch == '\t') {
          buffer.write(r'\t');
          continue;
        }

        if (ch == '"') {
          buffer.write(ch);
          inString = false;
          continue;
        }

        buffer.write(ch);
        continue;
      }

      if (ch == '"') {
        buffer.write(ch);
        inString = true;
        continue;
      }

      buffer.write(ch);
    }

    var output = buffer.toString();

    if (aggressive) {
      // 移除尾逗號：`, }` 或 `, ]`
      // 只做簡單修復（在非字串情境才可能有效；字串內已在上面處理）
      output = output.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
    }

    return output.trim();
  }

  String _buildSimilarPracticeGradeStrategy(String? gradeLevel) {
    if (gradeLevel == null || gradeLevel.isEmpty || gradeLevel == '不確定') {
      return '''
請預設以國中生可練習的難度出題，避免超出國中課綱的術語或解法。
''';
    }

    if (gradeLevel.startsWith('國')) {
      return '''
這題推定屬於 $gradeLevel。請務必保持在國中課綱與國中生可理解的難度內，不可跳用高中觀念。
''';
    }

    return '''
這題推定屬於 $gradeLevel。若能以更清楚的國中到高中銜接方式表達，請優先使用學生容易吸收的教學語氣。
''';
  }

  String _buildSimilarPracticeSubjectStrategy(String? subject) {
    switch (subject) {
      case '數學':
        return '''
【數學出題策略】
- 優先練單一核心觀念，例如方程式、比例、機率、代數化簡、基礎幾何性質。
- 改變數字、情境或問法，但保留相同觀念與相近難度。
- 解析請明確指出每一步為什麼這樣做，並提醒最常犯錯的地方。
- 若原題含圖，請改寫成不需要圖也能完整理解的文字題。
''';
      case '英文':
        return '''
【英文出題策略】
- 優先練文法、句型、單字或短篇閱讀理解。
- 題幹長度適中，避免過長閱讀造成額外負擔。
- 解析請用繁體中文說明關鍵語感、文法線索或選項差異。
''';
      case '國文':
        return '''
【國文出題策略】
- 優先練字詞、修辭、句意、文意理解或短篇閱讀。
- 題幹與文本長度適中，避免過長篇章。
- 解析請指出判斷線索，而不是只給結論。
''';
      case '自然':
        return '''
【自然出題策略】
- 優先練單一概念，如力學、熱學、酸鹼、生物基本概念、地科基礎判斷。
- 盡量用生活化情境幫助國中生理解。
- 若原題依賴圖表或實驗圖，請改寫成純文字可作答版本。
''';
      case '地理':
      case '歷史':
      case '公民':
        return '''
【社會科出題策略】
- 以觀念辨析、短材料理解、因果判斷或基本情境應用為主。
- 不可要求地圖、圖片或表格判讀。
- 解析請直接點出關鍵概念與容易混淆的地方。
''';
      default:
        return '''
【通用出題策略】
- 優先維持與原題相近的核心觀念與難度。
- 新題要短、清楚、適合國中生練習。
''';
    }
  }

  String _repairJsonStringBackslashes(String text) {
    try {
      return text.replaceAllMapped(RegExp(r'"(?:[^"\\]|\\.)*"'), (match) {
        final fullMatch = match.group(0)!;
        final content = fullMatch.substring(1, fullMatch.length - 1);
        final buffer = StringBuffer();

        for (var i = 0; i < content.length; i++) {
          final current = content[i];
          if (current != '\\') {
            buffer.write(current);
            continue;
          }

          if (i == content.length - 1) {
            buffer.write(r'\\');
            continue;
          }

          final next = content[i + 1];
          final isJsonEscape = next == '"' ||
              next == '\\' ||
              next == '/' ||
              next == 'b' ||
              next == 'f' ||
              next == 'n' ||
              next == 'r' ||
              next == 't';

          final isUnicodeEscape = next == 'u' && i + 5 < content.length;

          if (isJsonEscape || isUnicodeEscape) {
            buffer.write(current);
            buffer.write(next);
            i++;
            if (isUnicodeEscape) {
              for (var j = 0; j < 4; j++) {
                i++;
                buffer.write(content[i]);
              }
            }
            continue;
          }

          buffer.write(r'\\');
          buffer.write(next);
          i++;
        }

        return '"${buffer.toString()}"';
      });
    } catch (_) {
      return text;
    }
  }

  bool _containsPromptArtifacts(
    String text, {
    required String questionText,
  }) {
    final markers = [
      '你是一位具有 15 年教學經驗',
      '以下是透過 OCR 辨識的題目文字',
      '【重要分類規則',
      '【LaTeX 格式規則',
      '請你【嚴格】依照下列規則分析題目',
      '請確保所有內容都是繁體中文',
      'subject 判斷規則',
      '步驟 1：強制檢查數學符號',
    ];

    for (final marker in markers) {
      if (text.contains(marker)) return true;
    }

    if (questionText.isNotEmpty && text.contains('「$questionText」')) {
      return true;
    }

    return false;
  }
}
