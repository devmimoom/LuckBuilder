import 'dart:typed_data';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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

    final fonts = await _loadPdfFonts();
    final maxQuestionsPerPage = settings.questionsPerPage.count;
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Text(
            '我的錯題本',
            style: _pdfTextStyle(
              fonts,
              fontSize: 18,
              isBold: true,
            ),
          ),
        ),
        build: (context) {
          final widgets = <pw.Widget>[];
          for (var i = 0; i < sortedMistakes.length; i++) {
            widgets.addAll(
              _buildQuestionBlockWidgets(
                sortedMistakes[i],
                settings,
                fonts,
                imageCache,
              ),
            );
            final isLast = i == sortedMistakes.length - 1;
            final reachedPerPageCap = (i + 1) % maxQuestionsPerPage == 0;
            if (!isLast && reachedPerPageCap) {
              widgets.add(pw.NewPage());
            }
          }
          return widgets;
        },
      ),
    );

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

  static List<pw.Widget> _buildQuestionBlockWidgets(
    Mistake mistake,
    PrintSettings settings,
    _PdfFonts fonts,
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
    final imageHeight = switch (settings.questionsPerPage) {
      QuestionsPerPage.one => 180.0,
      QuestionsPerPage.two => 140.0,
      QuestionsPerPage.four => 96.0,
    };

    return [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                '[${mistake.subject}] ${mistake.category}',
                style: _pdfTextStyle(
                  fonts,
                  fontSize: 10,
                  color: PdfColors.blue800,
                ),
              ),
            ),
            if (settings.showDate)
              pw.Text(
                dateStr,
                style: _pdfTextStyle(
                  fonts,
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
          ],
        ),
      ),
      pw.SizedBox(height: 10),
      if (settings.includeImages &&
          mistake.imagePath.isNotEmpty &&
          imageCache[mistake.imagePath] != null) ...[
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(6),
            color: PdfColors.grey100,
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Center(
            child: pw.Image(
              imageCache[mistake.imagePath]!,
              height: imageHeight,
              fit: pw.BoxFit.contain,
            ),
          ),
        ),
      ],
      pw.Text(
        '題目：',
        style: _pdfTextStyle(
          fonts,
          fontSize: 12,
          isBold: true,
        ),
      ),
      pw.SizedBox(height: 4),
      _buildTextWithMath(mistake.title, fonts, fontSize: 11),
      if (detailSectionTitle != null && printableDetails.isNotEmpty) ...[
        pw.SizedBox(height: 12),
        pw.Text(
          detailSectionTitle,
          style: _pdfTextStyle(
            fonts,
            isBold: true,
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
              fonts,
              fontSize: 10,
              color: detailTextColor,
            ),
          );
        }),
      ],
      if (mistake.tagsForDisplay.isNotEmpty) ...[
        pw.SizedBox(height: 12),
        pw.Wrap(
          spacing: 4,
          runSpacing: 4,
          children: mistake.tagsForDisplay
              .map((tag) => pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      tag,
                      style: _pdfTextStyle(
                        fonts,
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
      pw.SizedBox(height: 16),
      pw.Divider(color: PdfColors.grey300),
      pw.SizedBox(height: 12),
    ];
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
    final parsedSolutions = _parseSolutions(mistake.solutions);
    switch (option) {
      case PrintContentOption.questionOnly:
        return const <String>[];
      case PrintContentOption.questionAndAnswer:
        final answers = _buildAnswerOnlyDetails(parsedSolutions);
        return answers.isNotEmpty ? answers : _buildFallbackDetails(parsedSolutions);
      case PrintContentOption.full:
        return _getPrintableSolutions(mistake.solutions);
      case PrintContentOption.withNote:
        final notes = _buildNoteDetails(parsedSolutions);
        return notes.isNotEmpty ? notes : const <String>['目前沒有可列印的筆記或提醒內容。'];
    }
  }

  static List<String> _getPrintableSolutions(List<String> solutions) {
    final parsedSolutions = _parseSolutions(solutions);
    final seen = <String>{};
    final printable = <String>[];

    for (final solution in parsedSolutions) {
      final parts = <String>[
        if (solution.title.isNotEmpty) solution.title,
        if (solution.content.isNotEmpty) solution.content,
      ];
      final normalized = _normalizePrintableText(parts.join('：'));
      if (normalized.isEmpty) continue;
      if (_containsPromptArtifacts(normalized)) continue;
      if (!seen.add(normalized)) continue;
      printable.add(normalized);
    }

    return printable;
  }

  static List<_PrintableSolution> _parseSolutions(List<String> solutions) {
    final parsed = <_PrintableSolution>[];

    for (final solution in solutions) {
      final normalized = _normalizePrintableText(solution);
      if (normalized.isEmpty) continue;

      final colonIndex = normalized.indexOf('：');
      if (colonIndex > 0) {
        parsed.add(
          _PrintableSolution(
            title: normalized.substring(0, colonIndex).trim(),
            content: colonIndex < normalized.length - 1
                ? normalized.substring(colonIndex + 1).trim()
                : '',
          ),
        );
      } else {
        parsed.add(_PrintableSolution(title: '', content: normalized));
      }
    }

    return parsed;
  }

  static List<String> _buildAnswerOnlyDetails(
    List<_PrintableSolution> solutions,
  ) {
    final seen = <String>{};
    final printable = <String>[];

    for (final solution in solutions) {
      final title = solution.title.trim();
      final content = solution.content.trim();
      if (content.isEmpty && title.isEmpty) continue;

      final lowerTitle = title.toLowerCase();
      if (title == '正確答案' ||
          lowerTitle.contains('答案') ||
          lowerTitle.contains('answer')) {
        final line = title.isEmpty ? content : '$title：$content';
        if (seen.add(line)) printable.add(line);
        continue;
      }

      final extracted = _extractAnswerSentence(content);
      if (extracted != null && seen.add(extracted)) {
        printable.add(extracted);
      }
    }

    return printable;
  }

  static List<String> _buildNoteDetails(
    List<_PrintableSolution> solutions,
  ) {
    final seen = <String>{};
    final printable = <String>[];

    for (final solution in solutions) {
      final title = solution.title.trim();
      final content = solution.content.trim();
      if (content.isEmpty && title.isEmpty) continue;

      final isNoteLike = title.contains('易錯') ||
          title.contains('提醒') ||
          title.contains('筆記') ||
          title.contains('正確答案') ||
          title.contains('依答案推斷');
      if (!isNoteLike) continue;

      final line = title.isEmpty ? content : '$title：$content';
      if (seen.add(line)) printable.add(line);
    }

    return printable;
  }

  static List<String> _buildFallbackDetails(
    List<_PrintableSolution> solutions,
  ) {
    for (final solution in solutions) {
      final title = solution.title.trim();
      final content = solution.content.trim();
      if (content.isEmpty) continue;
      if (title.contains('易錯') || title.contains('提醒')) continue;
      return [title.isEmpty ? content : '$title：$content'];
    }

    return const <String>['目前沒有可列印的答案內容。'];
  }

  static String? _extractAnswerSentence(String content) {
    final normalized = _normalizePrintableText(content);
    if (normalized.isEmpty) return null;

    final patterns = <RegExp>[
      RegExp(r'(所以答案是[^。；\n]*)'),
      RegExp(r'(答案是[^。；\n]*)'),
      RegExp(r'(故答案為[^。；\n]*)'),
      RegExp(r'(因此答案為[^。；\n]*)'),
      RegExp(r'(故選[^\n。；]*)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }

    return null;
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
    _PdfFonts fonts, {
    double fontSize = 11,
    PdfColor? color,
  }) {
    text = _normalizePdfText(
      _normalizeHighRiskGlyphsForPdf(
        LatexHelper.toReadableText(text, fallback: ''),
      ),
    );

    return pw.Text(
      text,
      style: _pdfTextStyle(
        fonts,
        fontSize: fontSize,
        color: color,
      ),
    );
  }

  static Future<_PdfFonts> _loadPdfFonts() async {
    try {
      final regular =
          await rootBundle.load('assets/fonts/NotoSansTC-Variable.ttf');
      final bold = await rootBundle.load('assets/fonts/NotoSansTC-Variable.ttf');
      final math =
          await rootBundle.load('assets/fonts/NotoSansMath-Regular.ttf');
      final symbols =
          await rootBundle.load('assets/fonts/NotoSansSymbols2-Regular.ttf');

      return _PdfFonts(
        regular: pw.Font.ttf(regular),
        bold: pw.Font.ttf(bold),
        math: pw.Font.ttf(math),
        symbols: pw.Font.ttf(symbols),
      );
    } catch (e) {
      throw Exception('無法載入 PDF 內建字體: $e');
    }
  }

  static pw.TextStyle _pdfTextStyle(
    _PdfFonts fonts, {
    double fontSize = 11,
    PdfColor? color,
    bool isBold = false,
  }) {
    return pw.TextStyle(
      font: isBold ? fonts.bold : fonts.regular,
      fontFallback: [fonts.math, fonts.symbols],
      fontSize: fontSize,
      color: color,
      lineSpacing: 2,
    );
  }

  static String _normalizePdfText(String text) {
    return text
        .replaceAll('\uFFFD', '')
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        // 保留 0305(上劃線) 與 0332(下劃線)，避免線段/底線符號再次被吃掉。
        .replaceAll(RegExp(r'[\u0300-\u0304\u0306-\u0331\u0333-\u036F]'), '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String _normalizeHighRiskGlyphsForPdf(String text) {
    const replacements = <String, String>{
      '⁰': '^0',
      '¹': '^1',
      '²': '^2',
      '³': '^3',
      '⁴': '^4',
      '⁵': '^5',
      '⁶': '^6',
      '⁷': '^7',
      '⁸': '^8',
      '⁹': '^9',
      '⁺': '^+',
      '⁻': '^-',
      '⁼': '^=',
      '⁽': '^(',
      '⁾': '^)',
      'ⁿ': '^n',
      'ⁱ': '^i',
      '₀': '_0',
      '₁': '_1',
      '₂': '_2',
      '₃': '_3',
      '₄': '_4',
      '₅': '_5',
      '₆': '_6',
      '₇': '_7',
      '₈': '_8',
      '₉': '_9',
      '₊': '_+',
      '₋': '_-',
      '₌': '_=',
      '₍': '_(',
      '₎': '_)',
      'ₐ': '_a',
      'ₑ': '_e',
      'ₕ': '_h',
      'ᵢ': '_i',
      'ⱼ': '_j',
      'ₖ': '_k',
      'ₗ': '_l',
      'ₘ': '_m',
      'ₙ': '_n',
      'ₒ': '_o',
      'ₚ': '_p',
      'ᵣ': '_r',
      'ₛ': '_s',
      'ₜ': '_t',
      'ᵤ': '_u',
      'ᵥ': '_v',
      'ₓ': '_x',
      '⃗': '→',
      '̂': '^',
      '̃': '~',
      '̇': '.',
      '̈': '..',
    };

    var normalized = text;
    replacements.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });
    return normalized;
  }
}

class _PdfFonts {
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font math;
  final pw.Font symbols;

  const _PdfFonts({
    required this.regular,
    required this.bold,
    required this.math,
    required this.symbols,
  });
}

class _PrintableSolution {
  final String title;
  final String content;

  const _PrintableSolution({
    required this.title,
    required this.content,
  });
}
