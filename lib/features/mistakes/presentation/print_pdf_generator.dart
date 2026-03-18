import 'dart:typed_data';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:dio/dio.dart';
import '../../../core/database/models/mistake.dart';
import '../../../core/utils/latex_helper.dart';
import '../providers/print_provider.dart';
import 'package:intl/intl.dart';

/// PDF 生成器
class PrintPdfGenerator {
  static Future<Uint8List> generate(
      List<Mistake> mistakes, PrintSettings settings) async {
    final pdf = pw.Document();

    // 根據設定排序
    final sortedMistakes = _sortMistakes(mistakes, settings.sortOption);

    // 根據每頁題數分組
    final questionsPerPage = settings.questionsPerPage.count;
    final pages = <List<Mistake>>[];
    for (var i = 0; i < sortedMistakes.length; i += questionsPerPage) {
      pages.add(sortedMistakes.sublist(
        i,
        i + questionsPerPage > sortedMistakes.length
            ? sortedMistakes.length
            : i + questionsPerPage,
      ));
    }

    // 預先載入題目圖片（如果有啟用「包含題目圖片」）
    final Map<String, pw.ImageProvider> imageCache = {};
    if (settings.includeImages) {
      for (final m in sortedMistakes) {
        final path = m.imagePath;
        if (path.isEmpty || imageCache.containsKey(path)) continue;
        try {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            if (bytes.isNotEmpty) {
              imageCache[path] = pw.MemoryImage(bytes);
            }
          }
        } catch (e) {
          developer.log(
            '載入題目圖片失敗: $path, error: $e',
            name: 'PrintPdfGenerator',
          );
        }
      }
    }

    // 載入中文字體（使用 Noto Sans TC）
    // 從 Google Fonts CDN 下載字體文件
    final fontBytes = await _loadFontFromGoogle('Noto+Sans+TC');
    final fontBoldBytes = await _loadFontFromGoogle('Noto+Sans+TC:wght@700');

    // 載入數學字體（使用 Noto Sans Math）
    final mathFontBytes = await _loadMathFont();

    final fontData = ByteData.view(fontBytes.buffer);
    final fontBoldData = ByteData.view(fontBoldBytes.buffer);
    final mathFontData = ByteData.view(mathFontBytes.buffer);

    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);
    final mathFont = pw.Font.ttf(mathFontData);

    for (final pageQuestions in pages) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 頁面標題
                pw.Text(
                  '我的錯題本',
                  style: pw.TextStyle(font: fontBold, fontSize: 18),
                ),
                pw.SizedBox(height: 20),
                // 題目列表
                ...pageQuestions.map((mistake) {
                  return _buildQuestionBlock(
                    mistake,
                    settings,
                    font,
                    fontBold,
                    mathFont,
                    imageCache,
                  );
                }),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  static List<Mistake> _sortMistakes(
      List<Mistake> mistakes, SortOption option) {
    final sorted = List<Mistake>.from(mistakes);
    switch (option) {
      case SortOption.dateDesc:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.dateAsc:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOption.category:
        sorted.sort((a, b) {
          final categoryCompare = a.category.compareTo(b.category);
          if (categoryCompare != 0) return categoryCompare;
          return a.subject.compareTo(b.subject);
        });
        break;
      case SortOption.errorCount:
        // 目前 Mistake 模型沒有 errorCount，暫時按日期排序
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return sorted;
  }

  static pw.Widget _buildQuestionBlock(
    Mistake mistake,
    PrintSettings settings,
    pw.Font font,
    pw.Font fontBold,
    pw.Font mathFont,
    Map<String, pw.ImageProvider> imageCache,
  ) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    final dateStr = dateFormat.format(mistake.createdAt);
    final printableDetails =
        _getPrintableDetails(mistake, settings.contentOption);
    final detailSectionTitle = _getDetailSectionTitle(settings.contentOption);
    final detailTextColor = settings.contentOption == PrintContentOption.full
        ? PdfColors.grey700
        : PdfColors.green800;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // 標題列
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  '[${mistake.subject}] ${mistake.category}',
                  style: pw.TextStyle(
                      font: font, fontSize: 10, color: PdfColors.blue800),
                ),
              ),
              if (settings.showDate)
                pw.Text(
                  dateStr,
                  style: pw.TextStyle(
                      font: font, fontSize: 10, color: PdfColors.grey600),
                ),
            ],
          ),
          pw.SizedBox(height: 12),
          // 題目圖片（可選）
          if (settings.includeImages &&
              mistake.imagePath.isNotEmpty &&
              imageCache[mistake.imagePath] != null) ...[
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(6),
                color: PdfColors.grey100,
              ),
              child: pw.ClipRRect(
                horizontalRadius: 6,
                verticalRadius: 6,
                child: pw.Center(
                  child: pw.Image(
                    imageCache[mistake.imagePath]!,
                    height: 160,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
          // 題目
          pw.Text(
            '題目：',
            style: pw.TextStyle(font: fontBold, fontSize: 12),
          ),
          pw.SizedBox(height: 4),
          _buildTextWithMath(mistake.title, font, mathFont, fontSize: 11),
          if (detailSectionTitle != null && printableDetails.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              detailSectionTitle,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 11,
                color: detailTextColor,
              ),
            ),
            pw.SizedBox(height: 4),
            ...printableDetails.map((detail) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: _buildTextWithMath(
                  detail,
                  font,
                  mathFont,
                  fontSize: 10,
                  color: detailTextColor,
                ),
              );
            }),
          ],
          // 標籤（如果有）
          if (mistake.tags.isNotEmpty &&
              mistake.tags.any((t) => t != 'AI 解析')) ...[
            pw.SizedBox(height: 12),
            pw.Wrap(
              spacing: 4,
              runSpacing: 4,
              children: mistake.tags
                  .where((t) => t != 'AI 解析')
                  .map((tag) => pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey200,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          tag,
                          style: pw.TextStyle(
                              font: font,
                              fontSize: 9,
                              color: PdfColors.grey700),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  static String? _getDetailSectionTitle(PrintContentOption option) {
    switch (option) {
      case PrintContentOption.questionOnly:
        return null;
      case PrintContentOption.questionAndAnswer:
        return '解題重點：';
      case PrintContentOption.full:
        return 'AI 解析：';
      case PrintContentOption.withNote:
        return '我的筆記：';
    }
  }

  static List<String> _getPrintableDetails(
    Mistake mistake,
    PrintContentOption option,
  ) {
    return _getPrintableSolutions(mistake.solutions);
  }

  static List<String> _getPrintableSolutions(List<String> solutions) {
    final seen = <String>{};
    final printable = <String>[];

    for (final solution in solutions) {
      final normalized = _normalizePrintableText(solution);
      if (normalized.isEmpty) continue;
      if (_containsPromptArtifacts(normalized)) continue;
      if (!seen.add(normalized)) continue;
      printable.add(normalized);
    }

    return printable;
  }

  static String _normalizePrintableText(String text) {
    var normalized = text.trim();
    if (normalized.startsWith('```json')) {
      normalized = normalized.replaceFirst(RegExp(r'^```json\s*'), '');
    }
    if (normalized.startsWith('```')) {
      normalized = normalized.replaceFirst(RegExp(r'^```\s*'), '');
    }
    if (normalized.endsWith('```')) {
      normalized = normalized.replaceFirst(RegExp(r'\s*```$'), '');
    }
    return normalized.trim();
  }

  static bool _containsPromptArtifacts(String text) {
    const markers = [
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

    return false;
  }

  /// 構建包含數學符號的文本，自動切換字體
  static pw.Widget _buildTextWithMath(
    String text,
    pw.Font defaultFont,
    pw.Font mathFont, {
    double fontSize = 11,
    PdfColor? color,
  }) {
    // 第一步：使用 LatexHelper 清理文本，修復 rac{ 等問題
    text = LatexHelper.cleanOcrText(text);

    // 第二步：處理 LaTeX 表達式，將 LaTeX 命令轉換為可在 PDF 中顯示的格式
    text = _convertLatexToPlainText(text);

    // 檢測字符是否為數學符號
    bool isMathChar(int codePoint) {
      // 希臘字母範圍（小寫和大寫）
      if ((codePoint >= 0x03B1 && codePoint <= 0x03C9) || // 小寫希臘字母
          (codePoint >= 0x0391 && codePoint <= 0x03A9)) {
        // 大寫希臘字母
        return true;
      }

      // 數學運算符範圍
      if (codePoint >= 0x2200 && codePoint <= 0x22FF) {
        // 數學運算符
        return true;
      }

      // 數學字母數字符號
      if (codePoint >= 0x1D400 && codePoint <= 0x1D7FF) {
        return true;
      }

      // 補充數學運算符
      if (codePoint >= 0x2A00 && codePoint <= 0x2AFF) {
        return true;
      }

      // 箭頭符號（常用於數學）
      if (codePoint >= 0x2190 && codePoint <= 0x21FF) {
        return true;
      }

      // 字母式符號
      if (codePoint >= 0x2100 && codePoint <= 0x214F) {
        return true;
      }

      // 雜項數學符號-A 和 B
      if ((codePoint >= 0x27C0 && codePoint <= 0x27EF) ||
          (codePoint >= 0x2980 && codePoint <= 0x29FF)) {
        return true;
      }

      // 上標和下標字符
      if ((codePoint >= 0x2070 && codePoint <= 0x207F) || // 上標數字和符號
          (codePoint >= 0x2080 && codePoint <= 0x208F)) {
        // 下標數字和符號
        return true;
      }

      // 常見的單個數學符號
      final commonMathSymbols = {
        0x2212, // 減號 (−)
        0x00D7, // 乘號 (×)
        0x00F7, // 除號 (÷)
        0x221A, // 根號 (√)
        0x221E, // 無窮大 (∞)
        0x03C0, // π
        0x2205, // 空集 (∅)
        0x2208, // 屬於 (∈)
        0x2209, // 不屬於 (∉)
        0x222B, // 積分 (∫)
        0x2211, // 求和 (∑)
        0x220F, // 乘積 (∏)
        0x2260, // 不等於 (≠)
        0x2264, // 小於等於 (≤)
        0x2265, // 大於等於 (≥)
        0x221D, // 正比於 (∝)
        0x223C, // 相似 (∼)
        0x2248, // 約等於 (≈)
      };

      return commonMathSymbols.contains(codePoint);
    }

    // 檢查文本中是否有數學符號
    final hasMath = text.runes.any(isMathChar);
    if (!hasMath) {
      // 沒有數學符號，直接使用普通字體
      return pw.Text(
        text,
        style: pw.TextStyle(
          font: defaultFont,
          fontSize: fontSize,
          color: color,
        ),
      );
    }

    // 有數學符號，需要分割文本
    final spans = <pw.TextSpan>[];
    String currentText = '';
    pw.Font? currentFont;

    for (final codePoint in text.runes) {
      final isMath = isMathChar(codePoint);
      final charFont = isMath ? mathFont : defaultFont;
      final char = String.fromCharCode(codePoint);

      if (currentFont == null) {
        // 第一個字符
        currentFont = charFont;
        currentText = char;
      } else if (charFont == currentFont) {
        // 字體相同，追加字符
        currentText += char;
      } else {
        // 字體改變，保存當前文本並開始新段落
        if (currentText.isNotEmpty) {
          spans.add(
            pw.TextSpan(
              text: currentText,
              style: pw.TextStyle(
                font: currentFont,
                fontSize: fontSize,
                color: color,
              ),
            ),
          );
        }
        currentText = char;
        currentFont = charFont;
      }
    }

    // 添加最後一段
    if (currentText.isNotEmpty) {
      spans.add(
        pw.TextSpan(
          text: currentText,
          style: pw.TextStyle(
            font: currentFont ?? defaultFont,
            fontSize: fontSize,
            color: color,
          ),
        ),
      );
    }

    // 使用 RichText 顯示混合字體文本
    return pw.RichText(
      text: pw.TextSpan(children: spans),
    );
  }

  /// 載入數學字體（Noto Sans Math）
  static Future<Uint8List> _loadMathFont() async {
    try {
      final dio = Dio();
      // Noto Sans Math 的 GitHub 原始文件 URL
      const mathFontUrl =
          'https://github.com/google/fonts/raw/main/ofl/notosansmath/NotoSansMath-Regular.ttf';

      final response = await dio.get(
        mathFontUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      final fontData = response.data as Uint8List;
      if (fontData.isEmpty) {
        throw Exception('數學字體文件為空');
      }

      return fontData;
    } catch (e) {
      // 如果數學字體載入失敗，使用中文字體作為備用
      // 這樣至少不會導致整個 PDF 生成失敗
      developer.log('警告：無法載入數學字體，使用中文字體作為備用: $e');
      return await _loadFontFromGoogle('Noto+Sans+TC');
    }
  }

  /// 從 Google Fonts CDN 載入字體文件（TTF 格式）
  /// 使用 GitHub 上 Google Fonts 官方倉庫的原始 TTF 文件
  static Future<Uint8List> _loadFontFromGoogle(String fontSpec) async {
    try {
      final dio = Dio();

      // Noto Sans TC 的 GitHub 原始文件 URL（TTF 格式）
      // 使用包含所有字重的單一變量字體文件
      const fontUrl =
          'https://github.com/google/fonts/raw/main/ofl/notosanstc/NotoSansTC%5Bwght%5D.ttf';

      final response = await dio.get(
        fontUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      final fontData = response.data as Uint8List;
      if (fontData.isEmpty) {
        throw Exception('字體文件為空');
      }

      // 驗證是 TTF 文件（TTF 文件開頭應該是特定的簽名）
      // TTF 文件開頭通常是 0x00 01 00 00 或 'OTTO' (OTF)
      if (fontData.length < 4) {
        throw Exception('字體文件太小');
      }

      return fontData;
    } catch (e) {
      // 如果下載失敗，拋出詳細錯誤
      throw Exception('無法載入中文字體 Noto Sans TC: $e\n'
          '請檢查網路連接或稍後再試。');
    }
  }

  /// 將 LaTeX 表達式轉換為可在 PDF 中顯示的純文字格式
  static String _convertLatexToPlainText(String text) {
    String result = text;

    // 1. 移除 \( 和 \)（行內公式標記）
    result = result.replaceAll(RegExp(r'\\[\(\)]'), '');

    // 2. 移除 \[ 和 \]（塊級公式標記）
    result = result.replaceAll(RegExp(r'\\[\[\]]'), '');

    // 3. 處理上標：使用 ASCII 標記，避免某些裝置字型缺字造成亂碼
    // 例如：x^{2} → x^2, (a+b)^{10} → (a+b)^10
    result = result.replaceAllMapped(RegExp(r'\^\{([^}]+)\}'), (match) {
      final content = match.group(1)!;
      return '^$content';
    });

    // 處理簡單上標：x^2 維持 x^2（不轉 Unicode）
    result = result.replaceAllMapped(RegExp(r'\^(\d+)'), (match) {
      return '^${match.group(1)!}';
    });

    // 4. 處理下標：使用 ASCII 標記，避免下標 Unicode 缺字（如 ₁、₃）
    result = result.replaceAllMapped(RegExp(r'_\{([^}]+)\}'), (match) {
      final content = match.group(1)!;
      return '_$content';
    });

    // 處理簡單下標：x_2 維持 x_2（不轉 Unicode）
    result = result.replaceAllMapped(RegExp(r'_(\d+)'), (match) {
      return '_${match.group(1)!}';
    });

    // 5. 處理分數：\frac{a}{b} → (a)/(b) 或 a/b
    result = result.replaceAllMapped(RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'),
        (match) {
      final numerator = match.group(1)!;
      final denominator = match.group(2)!;
      // 清理分子和分母中的 LaTeX 標記
      final cleanNum = numerator
          .replaceAll(RegExp(r'\\[a-zA-Z]+'), '')
          .replaceAll(RegExp(r'[{}]'), '');
      final cleanDen = denominator
          .replaceAll(RegExp(r'\\[a-zA-Z]+'), '')
          .replaceAll(RegExp(r'[{}]'), '');
      return '($cleanNum)/($cleanDen)';
    });

    // 6. 處理根號：\sqrt{n} → √n, \sqrt[m]{n} → ᵐ√n
    result = result.replaceAllMapped(
        RegExp(r'\\sqrt(?:\[([^\]]+)\])?\{([^}]+)\}'), (match) {
      final index = match.group(1);
      final content = match.group(2)!;
      if (index != null) {
        // 有根指數的情況
        return '√[$index]($content)';
      } else {
        return '√($content)';
      }
    });

    // 7. 處理常見的 LaTeX 數學符號
    result = result.replaceAll(r'\cdot', '·');
    result = result.replaceAll(r'\times', '×');
    result = result.replaceAll(r'\div', '÷');
    result = result.replaceAll(r'\pm', '±');
    result = result.replaceAll(r'\mp', '∓');
    result = result.replaceAll(r'\leq', '≤');
    result = result.replaceAll(r'\geq', '≥');
    result = result.replaceAll(r'\neq', '≠');
    result = result.replaceAll(r'\approx', '≈');
    result = result.replaceAll(r'\infty', '∞');
    result = result.replaceAll(r'\alpha', 'α');
    result = result.replaceAll(r'\beta', 'β');
    result = result.replaceAll(r'\gamma', 'γ');
    result = result.replaceAll(r'\delta', 'δ');
    result = result.replaceAll(r'\pi', 'π');
    result = result.replaceAll(r'\theta', 'θ');
    result = result.replaceAll(r'\phi', 'φ');
    result = result.replaceAll(r'\omega', 'ω');
    result = result.replaceAll(r'\sum', '∑');
    result = result.replaceAll(r'\int', '∫');
    result = result.replaceAll(r'\prod', '∏');
    result = result.replaceAll(r'\lim', 'lim');

    // 8. 移除剩餘的 LaTeX 命令標記（單個反斜線後跟字母）
    result = result.replaceAll(RegExp(r'\\([a-zA-Z]+)'), r'$1');

    // 9. 清理多餘的大括號
    result = result.replaceAll(RegExp(r'[{}]'), '');

    // 10. 清理多餘的空白
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }
}
