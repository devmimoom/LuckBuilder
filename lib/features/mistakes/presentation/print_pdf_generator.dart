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

    final fonts = await _loadPdfFonts();

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
                  style: _pdfTextStyle(
                    fonts,
                    fontSize: 18,
                    isBold: true,
                  ),
                ),
                pw.SizedBox(height: 20),
                // 題目列表
                ...pageQuestions.map((mistake) {
                  return _buildQuestionBlock(
                    mistake,
                    settings,
                    fonts,
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
