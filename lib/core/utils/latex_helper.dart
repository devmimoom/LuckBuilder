import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import '../theme/app_fonts.dart';

/// LaTeX 和文字處理工具類
class LatexHelper {
  /// 清理 OCR 結果，移除不必要的文字
  /// 例如：移除 "特別拿出來說的是這個：111署考数学 年 15 䟎" 這類的雜訊
  static String cleanOcrText(String? text) {
    if (text == null || text.isEmpty) return '';

    String cleaned = text;

    // 0. 移除控制字元（優先處理，避免後續處理問題）
    // 移除 ASCII 控制字元（0x00-0x1F），保留換行符（\n = 0x0A）和回車符（\r = 0x0D）
    cleaned =
        cleaned.replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]'), '');
    // 移除 C1 控制字元（0x80-0x9F）
    cleaned = cleaned.replaceAll(RegExp(r'[\u0080-\u009F]'), '');

    // 移除常見的 OCR 雜訊模式
    // 1. 移除 "特別拿出來說的是這個：" 這類前綴
    cleaned = cleaned.replaceAll(RegExp(r'特別拿出來說的是這個[：:]\s*'), '');

    // 2. 移除 "111署考数学 年 15 䟎" 這類題號雜訊
    cleaned =
        cleaned.replaceAll(RegExp(r'\d+署考[数学學]\s*年\s*\d+\s*[^\w\s]*'), '');

    // 3. 移除開頭的數字和特殊符號（題號）
    cleaned = cleaned.replaceAll(RegExp(r'^[\d\s．.\-]*'), '');

    // 4. 處理表格：如果檢測到 LaTeX 表格（\begin{tabular} 等），用"（如圖）"代替
    if (cleaned.contains(r'\begin{tabular}') ||
        cleaned.contains(r'\begin{array}')) {
      // 匹配完整的表格環境（從 \begin 到對應的 \end）
      cleaned = cleaned.replaceAllMapped(
        RegExp(r'\\begin\{tabular\}.*?\\end\{tabular\}', dotAll: true),
        (match) => '（如圖）',
      );
      cleaned = cleaned.replaceAllMapped(
        RegExp(r'\\begin\{array\}.*?\\end\{array\}', dotAll: true),
        (match) => '（如圖）',
      );
    }

    // 檢測其他表格相關的模式（如果沒有被上面的規則處理）
    // 檢測連續的 \hline 和表格結構
    if (cleaned.contains(r'\hline') && cleaned.contains(r'&')) {
      // 簡單的表格檢測：包含 \hline 和 & 符號
      // 這裡使用更簡單的方法：如果包含表格相關符號，但沒有完整的表格環境，保留原樣
      // 因為完整的表格環境已經被上面的規則處理了
    }

    // 5. 移除多餘的空白和換行
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 6. 移除開頭的 "圖（六）" 這類圖表標註（如果不在題目中間）
    cleaned = cleaned.replaceAll(RegExp(r'^圖[（(][^）)]+[）)]\s*'), '');

    // 7. 根據 Gemini prompt 規則驗證和修復 LaTeX 格式
    cleaned = validateAndFixLatexFormat(cleaned);

    return cleaned;
  }

  /// 根據 Gemini prompt 規則驗證和修復 LaTeX 格式
  /// 對應 Gemini prompt 中的【LaTeX 格式規則（嚴格遵守）】
  static String validateAndFixLatexFormat(String text) {
    if (text.isEmpty) return text;

    String cleaned = text;

    // 規則 0: 修復常見的截斷錯誤（rac{ → \frac{，最高優先級）
    // 這可能是因為之前的處理步驟錯誤地移除了 \frac 的第一個字符
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(?<!\\)\brac\{'),
      (match) => r'\frac{',
    );

    // 規則 4: 禁止在文字末尾添加反斜線
    // 移除行尾的獨立反斜線（禁止在公式內外使用反斜線表示換行）
    // 但要小心不要移除 LaTeX 命令中的反斜線
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\\(?!\\[a-zA-Z])\s*\n'),
      (match) => '\n',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\\(?!\\[a-zA-Z])\s*$', multiLine: true),
      (match) => '',
    );

    // 規則 5: 確保 LaTeX 指令前只有一個反斜線
    // 修復明顯的錯誤（\\\\frac → \frac），但要小心不要破壞正確的轉義
    // 先處理連續三個或更多反斜線的情況：\\\\\frac → \frac
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\\\\+([a-zA-Z]+)'),
      (match) {
        final backslashes = match.group(0)!.split('\\').length - 1;
        // 如果是奇數個反斜線（如 \\\\frac），保留一個；如果是偶數個（如 \\\\frac），保留一個
        return backslashes % 2 == 0
            ? r'\' + match.group(1)!
            : r'\' + match.group(1)!;
      },
    );

    // 規則 6: 驗證並修復不配對的公式標記
    // 計算 \( 和 \) 的數量
    final openInlineMatches = RegExp(r'\\\(').allMatches(cleaned);
    final closeInlineMatches = RegExp(r'\\\)').allMatches(cleaned);
    final openInline = openInlineMatches.length;
    final closeInline = closeInlineMatches.length;

    // 計算 \[ 和 \] 的數量
    final openBlockMatches = RegExp(r'\\\[').allMatches(cleaned);
    final closeBlockMatches = RegExp(r'\\\]').allMatches(cleaned);
    final openBlock = openBlockMatches.length;
    final closeBlock = closeBlockMatches.length;

    // 如果 \( 比 \) 多，在最後補上缺失的 \)
    if (openInline > closeInline) {
      final missing = openInline - closeInline;
      cleaned = cleaned + r'\)' * missing;
    }

    // 如果 \[ 比 \] 多，在最後補上缺失的 \]
    if (openBlock > closeBlock) {
      final missing = openBlock - closeBlock;
      cleaned = cleaned + r'\]' * missing;
    }

    // 規則 7: 移除禁止的水平線（--- 和 ***）
    // 移除獨立成行的水平線
    cleaned = cleaned.replaceAll(RegExp(r'^\s*-{3,}\s*$', multiLine: true), '');
    cleaned =
        cleaned.replaceAll(RegExp(r'^\s*\*{3,}\s*$', multiLine: true), '');

    // 規則 3: 確保沒有遺漏的禁止符號
    // $...$ 和 $$...$$ 已在 _ultimatePreprocess 中處理，這裡處理可能的遺漏
    // 將殘留的 $...$ 轉換為 \(...\)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\$([^\$]+)\$'),
      (match) => r'\(' + match.group(1)! + r'\)',
    );

    // 將殘留的 $$...$$ 轉換為 \[...\]
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\$\$([^\$]+)\$\$'),
      (match) => r'\[' + match.group(1)! + r'\]',
    );

    return cleaned;
  }

  /// 檢查文字是否包含 LaTeX 數學公式
  static bool containsLatex(String text) {
    return text.contains(RegExp(r'\\[\(\)]|\\frac|\\sqrt|\\sum|\\int|\\lim'));
  }

  /// 轉成適合一般 Text / TextField 顯示的可讀文字，避免直接看到 LaTeX 原始字串
  static String toReadableText(String? text, {String fallback = ''}) {
    final cleanedText = cleanOcrText(text);
    if (cleanedText.isEmpty) return fallback;

    String result = _normalizeReadableOcrNoise(cleanedText);

    result = result.replaceAll(RegExp(r'\\[\(\)]'), '');
    result = result.replaceAll(RegExp(r'\\[\[\]]'), '');
    result = result.replaceAll(r'\{', '{');
    result = result.replaceAll(r'\}', '}');

    result = result.replaceAll(
      RegExp(
        r'\\(?:left|right|big|Big|bigl|bigr|Bigl|Bigr|biggl|biggr|Biggl|Biggr)\s*',
      ),
      '',
    );
    result = result.replaceAll(
      RegExp(r'\\(?:,|;|:|!|quad|qquad)'),
      ' ',
    );

    result = _convertReadableAccentCommands(result);
    result = _stripReadableWrapperCommands(result);
    result = _convertReadableFractions(result);
    result = _convertReadableRoots(result);
    result = _convertReadableScripts(result);

    const replacements = <String, String>{
      r'\cdot': '·',
      r'\times': '×',
      r'\div': '÷',
      r'\pm': '±',
      r'\mp': '∓',
      r'\leq': '≤',
      r'\le': '≤',
      r'\geq': '≥',
      r'\ge': '≥',
      r'\neq': '≠',
      r'\ne': '≠',
      r'\approx': '≈',
      r'\sim': '∼',
      r'\propto': '∝',
      r'\infty': '∞',
      r'\alpha': 'α',
      r'\beta': 'β',
      r'\gamma': 'γ',
      r'\delta': 'δ',
      r'\pi': 'π',
      r'\theta': 'θ',
      r'\phi': 'φ',
      r'\omega': 'ω',
      r'\sum': '∑',
      r'\int': '∫',
      r'\prod': '∏',
      r'\rightarrow': '→',
      r'\to': '→',
      r'\leftarrow': '←',
      r'\gets': '←',
      r'\leftrightarrow': '↔',
      r'\mapsto': '↦',
      r'\uparrow': '↑',
      r'\downarrow': '↓',
      r'\updownarrow': '↕',
      r'\Rightarrow': '⇒',
      r'\Leftarrow': '⇐',
      r'\Leftrightarrow': '⇔',
      r'\implies': '⇒',
      r'\impliedby': '⇐',
      r'\iff': '⇔',
      r'\in': '∈',
      r'\notin': '∉',
      r'\subseteq': '⊆',
      r'\subset': '⊂',
      r'\subsetneq': '⊊',
      r'\supseteq': '⊇',
      r'\supset': '⊃',
      r'\supsetneq': '⊋',
      r'\nsubseteq': '⊈',
      r'\nsupseteq': '⊉',
      r'\cup': '∪',
      r'\cap': '∩',
      r'\emptyset': '∅',
      r'\setminus': '∖',
      r'\land': '∧',
      r'\lor': '∨',
      r'\neg': '¬',
      r'\oplus': '⊕',
      r'\otimes': '⊗',
      r'\bullet': '•',
      r'\ast': '*',
      r'\star': '⋆',
      r'\forall': '∀',
      r'\exists': '∃',
      r'\therefore': '∴',
      r'\because': '∵',
      r'\parallel': '∥',
      r'\perp': '⊥',
      r'\angle': '∠',
      r'\triangle': '△',
      r'\square': '□',
      r'\Box': '□',
      r'\Delta': 'Δ',
      r'\Gamma': 'Γ',
      r'\Theta': 'Θ',
      r'\Lambda': 'Λ',
      r'\Sigma': 'Σ',
      r'\Phi': 'Φ',
      r'\Psi': 'Ψ',
      r'\Omega': 'Ω',
      r'\lambda': 'λ',
      r'\mu': 'μ',
      r'\sigma': 'σ',
      r'\tau': 'τ',
      r'\epsilon': 'ε',
      r'\varepsilon': 'ε',
      r'\eta': 'η',
      r'\rho': 'ρ',
      r'\kappa': 'κ',
      r'\xi': 'ξ',
      r'\zeta': 'ζ',
      r'\chi': 'χ',
      r'\psi': 'ψ',
      r'\ell': 'l',
      r'\circ': '°',
      r'\degree': '°',
      r'\ldots': '...',
      r'\cdots': '...',
      r'\dots': '...',
    };
    replacements.forEach((latex, plain) {
      result = result.replaceAll(latex, plain);
    });

    result = result.replaceAll(RegExp(r'\\([a-zA-Z]+)'), r'$1');
    result = result.replaceAll(RegExp(r'[{}]'), '');
    result = result.replaceAllMapped(
      RegExp(r'\s*([=+\-×÷/<>≤≥≈∈∉⊂⊆⊃⊇∪∩])\s*'),
      (match) => ' ${match.group(1)!} ',
    );
    result = result.replaceAllMapped(
      RegExp(r'\s+([,.;:!?])'),
      (match) => match.group(1)!,
    );
    result = result.replaceAllMapped(
      RegExp(r'([([{])\s+'),
      (match) => match.group(1)!,
    );
    result = result.replaceAllMapped(
      RegExp(r'\s+([)\]}])'),
      (match) => match.group(1)!,
    );
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result.isEmpty ? fallback : result;
  }

  static String _normalizeReadableOcrNoise(String text) {
    String result = text;

    // 先將雙反斜線還原成單反斜線，避免顯示成 \\overline 這類亂碼
    result = result.replaceAll(r'\\', r'\');
    // 移除被轉義的 $，避免出現 \$1AB 這類片段
    result = result.replaceAll(r'\$', r'$');
    // OCR 常把角符號識別成 $1 / §1 / S1
    result = result.replaceAll(RegExp(r'[\$§S]1(?=[A-Za-z0-9])'), '∠');
    // OCR 常將兩條平行線辨識成 //
    result =
        result.replaceAll(RegExp(r'(?<=[A-Za-z0-9])//(?=[A-Za-z0-9])'), '∥');
    // OCR 常將垂直誤成 _|_ 或 ⊥ 的變形
    result = result.replaceAll('_|_', '⊥');
    // 將常見 escaped 百分比與底線還原
    result = result.replaceAll(r'\%', '%');
    result = result.replaceAll(r'\_', '_');

    return result;
  }

  static String _stripReadableWrapperCommands(String text) {
    String result = text;
    final wrapperPattern = RegExp(
      r'\\(?:text|mathrm|mathbf|mathit|textbf|textit|operatorname|operatorname\*)\{([^{}]*)\}',
    );
    while (wrapperPattern.hasMatch(result)) {
      result = result.replaceAllMapped(
        wrapperPattern,
        (match) => match.group(1) ?? '',
      );
    }
    return result;
  }

  static String _convertReadableAccentCommands(String text) {
    String result = text;

    final accentPatterns = <RegExp, String Function(Match match)>{
      RegExp(r'\\overrightarrow\{([^{}]+)\}'): (match) => '${match.group(1)!}→',
      RegExp(r'\\overleftarrow\{([^{}]+)\}'): (match) => '←${match.group(1)!}',
      RegExp(r'\\overleftrightarrow\{([^{}]+)\}'): (match) =>
          '↔${match.group(1)!}',
      RegExp(r'\\vec\{([^{}]+)\}'): (match) => '${match.group(1)!}⃗',
      RegExp(r'\\widehat\{([^{}]+)\}'): (match) => '${match.group(1)!}̂',
      RegExp(r'\\hat\{([^{}]+)\}'): (match) => '${match.group(1)!}̂',
      RegExp(r'\\widetilde\{([^{}]+)\}'): (match) => '${match.group(1)!}̃',
      RegExp(r'\\tilde\{([^{}]+)\}'): (match) => '${match.group(1)!}̃',
      RegExp(r'\\overline\{([^{}]+)\}'): (match) =>
          _applyCombiningMark(match.group(1)!, '\u0305'),
      RegExp(r'\\underline\{([^{}]+)\}'): (match) =>
          _applyCombiningMark(match.group(1)!, '\u0332'),
      RegExp(r'\\bar\{([^{}]+)\}'): (match) =>
          _applyCombiningMark(match.group(1)!, '\u0305'),
      RegExp(r'\\dot\{([^{}]+)\}'): (match) => '${match.group(1)!}̇',
      RegExp(r'\\ddot\{([^{}]+)\}'): (match) => '${match.group(1)!}̈',
      RegExp(r'\\boxed\{([^{}]+)\}'): (match) => '[${match.group(1)!}]',
      RegExp(r'\\cancel\{([^{}]+)\}'): (match) => match.group(1)!,
      RegExp(r'\\bcancel\{([^{}]+)\}'): (match) => match.group(1)!,
      RegExp(r'\\xcancel\{([^{}]+)\}'): (match) => match.group(1)!,
    };

    accentPatterns.forEach((pattern, builder) {
      while (pattern.hasMatch(result)) {
        result = result.replaceAllMapped(pattern, builder);
      }
    });

    return result;
  }

  static String _convertReadableFractions(String text) {
    String result = text;
    final fractionPattern = RegExp(
      r'\\(?:frac|dfrac|tfrac|cfrac)\{([^{}]+)\}\{([^{}]+)\}',
    );

    while (fractionPattern.hasMatch(result)) {
      result = result.replaceAllMapped(fractionPattern, (match) {
        String numerator = match.group(1)!.trim();
        String denominator = match.group(2)!.trim();

        if (_needsReadableParens(numerator)) numerator = '($numerator)';
        if (_needsReadableParens(denominator)) denominator = '($denominator)';

        return '$numerator/$denominator';
      });
    }

    return result;
  }

  static String _convertReadableRoots(String text) {
    String result = text;
    final rootPattern = RegExp(r'\\sqrt(?:\[([^\]]+)\])?\{([^{}]+)\}');

    while (rootPattern.hasMatch(result)) {
      result = result.replaceAllMapped(rootPattern, (match) {
        final index = match.group(1)?.trim();
        final content = match.group(2)!.trim();

        if (index == null || index.isEmpty || index == '2') {
          return '√($content)';
        }
        if (index == '3') {
          return '∛($content)';
        }
        if (index == '4') {
          return '∜($content)';
        }

        return '${_toSuperscriptText(index)}√($content)';
      });
    }

    return result;
  }

  static String _convertReadableScripts(String text) {
    String result = text;

    result = result.replaceAllMapped(RegExp(r'\^\{([^}]+)\}'), (match) {
      return _toSuperscriptText(match.group(1)!);
    });
    result =
        result.replaceAllMapped(RegExp(r'\^([A-Za-z0-9+\-=()]+)'), (match) {
      return _toSuperscriptText(match.group(1)!);
    });

    result = result.replaceAllMapped(RegExp(r'_\{([^}]+)\}'), (match) {
      return _toSubscriptText(match.group(1)!);
    });
    result = result.replaceAllMapped(RegExp(r'_([A-Za-z0-9+\-=()]+)'), (match) {
      return _toSubscriptText(match.group(1)!);
    });

    return result;
  }

  static bool _needsReadableParens(String value) {
    return RegExp(r'[+\-×÷*/=<>≤≥≈]|\s').hasMatch(value);
  }

  static String _toSuperscriptText(String text) {
    const map = <String, String>{
      '0': '⁰',
      '1': '¹',
      '2': '²',
      '3': '³',
      '4': '⁴',
      '5': '⁵',
      '6': '⁶',
      '7': '⁷',
      '8': '⁸',
      '9': '⁹',
      '+': '⁺',
      '-': '⁻',
      '=': '⁼',
      '(': '⁽',
      ')': '⁾',
      'n': 'ⁿ',
      'i': 'ⁱ',
    };
    return _mapScriptText(text, map, '^');
  }

  static String _toSubscriptText(String text) {
    const map = <String, String>{
      '0': '₀',
      '1': '₁',
      '2': '₂',
      '3': '₃',
      '4': '₄',
      '5': '₅',
      '6': '₆',
      '7': '₇',
      '8': '₈',
      '9': '₉',
      '+': '₊',
      '-': '₋',
      '=': '₌',
      '(': '₍',
      ')': '₎',
      'a': 'ₐ',
      'e': 'ₑ',
      'h': 'ₕ',
      'i': 'ᵢ',
      'j': 'ⱼ',
      'k': 'ₖ',
      'l': 'ₗ',
      'm': 'ₘ',
      'n': 'ₙ',
      'o': 'ₒ',
      'p': 'ₚ',
      'r': 'ᵣ',
      's': 'ₛ',
      't': 'ₜ',
      'u': 'ᵤ',
      'v': 'ᵥ',
      'x': 'ₓ',
    };
    return _mapScriptText(text, map, '_');
  }

  static String _mapScriptText(
    String text,
    Map<String, String> charMap,
    String fallbackPrefix,
  ) {
    final mapped = text.split('').map((char) => charMap[char]).toList();
    if (mapped.every((char) => char != null)) {
      return mapped.join();
    }
    return '$fallbackPrefix($text)';
  }

  static String _applyCombiningMark(String text, String combiningMark) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (char.trim().isEmpty) {
        buffer.write(char);
      } else {
        buffer.write(char);
        buffer.write(combiningMark);
      }
    }
    return buffer.toString();
  }

  // ============================================================
  // 以下為統一的前處理方法（供 LatexText 和 SafeMathTextWidget 共用）
  // ============================================================

  /// 包裹裸露的 LaTeX 指令（未被 \( \) 或 \[ \] 包裹的 LaTeX 命令）
  /// 當 Gemini 回傳的 LaTeX 公式沒有用 \( \) 包裹時，自動偵測並包裹
  /// 例如："\frac{1+17}{2}" → "\(\frac{1+17}{2}\)"
  static String wrapBareLatexCommands(String text) {
    if (text.isEmpty) return text;

    // 雙參數指令（如 \frac{a}{b}）
    const dualArgCommands = <String>{
      'frac',
      'dfrac',
      'tfrac',
      'binom',
      'dbinom',
      'cfrac',
    };
    // 單參數指令（如 \sqrt{x}，\sqrt 也可能有可選參數 \sqrt[n]{x}）
    const singleArgCommands = <String>{
      'sqrt',
      'overline',
      'underline',
      'bar',
      'hat',
      'vec',
      'dot',
      'ddot',
      'tilde',
      'widetilde',
      'widehat',
      'overrightarrow',
      'overleftarrow',
      'text',
      'textbf',
      'textit',
      'mathrm',
      'mathbf',
      'mathit',
      'mathbb',
      'mathcal',
      'boldsymbol',
      'boxed',
    };
    // 無參數指令（獨立符號，後面不接 {} 也是合法的 LaTeX）
    const standaloneCommands = <String>{
      'angle',
      'parallel',
      'perp',
      'triangle',
      'square',
      'circ',
      'degree',
      'prime',
      'ell',
      'forall',
      'exists',
      'nabla',
      'therefore',
      'because',
    };

    final allCommands = <String>{
      ...dualArgCommands,
      ...singleArgCommands,
      ...standaloneCommands,
    };

    // Step 1: 找出所有已在 \(...\) 或 \[...\] 中的區域，避免重複包裹
    List<List<int>> buildMathRegions(String source) {
      final regions = <List<int>>[];
      final inlinePattern = RegExp(r'\\\(.*?\\\)', dotAll: true);
      for (final match in inlinePattern.allMatches(source)) {
        regions.add([match.start, match.end]);
      }
      final blockPattern = RegExp(r'\\\[.*?\\\]', dotAll: true);
      for (final match in blockPattern.allMatches(source)) {
        regions.add([match.start, match.end]);
      }
      return regions;
    }

    List<List<int>> mathRegions = buildMathRegions(text);

    bool isInsideMath(String source, List<List<int>> regions, int pos) {
      return regions.any((r) => pos >= r[0] && pos < r[1]);
    }

    // 檢查某個位置是否在花括號 {...} 內部（表示是其他 LaTeX 指令的參數）
    // 例如 \frac{\frac{a}{b}}{c} 中，內部的 \frac 在外層 \frac 的 {} 裡
    bool isInsideBraces(int pos) {
      int depth = 0;
      for (int i = 0; i < pos && i < text.length; i++) {
        if (text[i] == '{') {
          depth++;
        } else if (text[i] == '}') {
          depth--;
        }
      }
      return depth > 0;
    }

    // Step 2: 用 regex 找出所有裸露的 LaTeX 指令
    final commandNames = allCommands.join('|');
    // 匹配 \command 後面跟著 {、[、空白、^、_ 或字串結尾
    final barePattern =
        RegExp(r'\\(' + commandNames + r')(?=[\{\[\s\^\_\,\;\.\)\=\+\-]|$)');
    final bareMatches = barePattern
        .allMatches(text)
        .where((m) =>
            !isInsideMath(text, mathRegions, m.start) &&
            !isInsideBraces(m.start))
        .toList();

    // Step 2.5: 先處理裸露的 \left ... \right 配對，將整段用 \( ... \) 包起來
    String result = text;
    final leftPattern = RegExp(r'\\left');
    final rightPattern = RegExp(r'\\right');
    final leftMatches = leftPattern.allMatches(result).toList();
    if (leftMatches.isNotEmpty) {
      // 從後往前處理，避免索引位移
      for (final match in leftMatches.reversed) {
        final start = match.start;
        if (isInsideMath(result, mathRegions, start)) continue;

        int depth = 0;
        int i = start;
        int? rightEnd;
        while (i < result.length) {
          final lm = leftPattern.matchAsPrefix(result, i);
          final rm = rightPattern.matchAsPrefix(result, i);
          if (lm != null) {
            depth++;
            i = lm.end;
            continue;
          }
          if (rm != null) {
            depth--;
            i = rm.end;
            // 嘗試讀取 right 後面的定界符（例如 \right) 或 \right]
            if (i < result.length) {
              i++;
            }
            if (depth <= 0) {
              rightEnd = i;
              break;
            }
            continue;
          }
          i++;
        }
        if (rightEnd != null) {
          result =
              '${result.substring(0, start)}\\(${result.substring(start, rightEnd)}\\)${result.substring(rightEnd)}';
        }
      }
      // 更新 math 區域，讓後續一般指令偵測不會再包裹已經處理過的區塊
      mathRegions = buildMathRegions(result);
    }

    if (bareMatches.isEmpty) return result;

    // Step 3: 從後往前處理每個裸露指令，找到完整表達式範圍後用 \( ... \) 包裹
    for (final match in bareMatches.reversed) {
      final cmdName = match.group(1)!;
      final int exprStart = match.start;
      int exprEnd = match.end;

      if (dualArgCommands.contains(cmdName)) {
        // 找兩個花括號群組：\frac{...}{...}
        final first = _findBraceGroup(result, exprEnd);
        if (first != null) {
          final second = _findBraceGroup(result, first);
          exprEnd = second ?? first;
        }
      } else if (singleArgCommands.contains(cmdName)) {
        // 處理 \sqrt[n]{...} 的可選參數
        int pos = exprEnd;
        if (cmdName == 'sqrt' && pos < result.length && result[pos] == '[') {
          final closeBracket = result.indexOf(']', pos);
          if (closeBracket != -1) {
            pos = closeBracket + 1;
          }
        }
        // 找一個花括號群組
        final end = _findBraceGroup(result, pos);
        if (end != null) {
          exprEnd = end;
        }
      }
      // standalone 指令不需要找花括號，exprEnd 就是指令名結束的位置

      // 用 \( ... \) 包裹
      result =
          '${result.substring(0, exprStart)}\\(${result.substring(exprStart, exprEnd)}\\)${result.substring(exprEnd)}';
    }

    return result;
  }

  /// 找到從 startIndex 開始的花括號群組的結束位置（右花括號之後）
  /// 支援巢狀花括號，例如 {a{b}c}
  /// 回傳右花括號之後的位置，找不到則回傳 null
  static int? _findBraceGroup(String text, int startIndex) {
    int i = startIndex;
    // 跳過空白
    while (i < text.length && (text[i] == ' ' || text[i] == '\n')) {
      i++;
    }

    if (i >= text.length || text[i] != '{') return null;

    int depth = 0;
    for (; i < text.length; i++) {
      if (text[i] == '{') {
        depth++;
      } else if (text[i] == '}') {
        depth--;
        if (depth == 0) return i + 1;
      }
    }
    return null; // 花括號不配對
  }

  /// 統一的終極前處理函式（供 LatexText / SafeMathTextWidget 共用）
  /// 多階段清洗和轉換，解決各種 LaTeX 格式問題：
  /// 0. 處理 `1n` 問題
  /// 1. 移除行尾的獨立反斜線
  /// 2. 雙重括號問題 `((...))` → `\(...\)`
  /// 3. 標準化分隔符 `$...$` → `\(...\)`
  /// 3.5 包裹裸露的 LaTeX 指令（新增！）
  /// 4. 修復不完整的 LaTeX 公式（缺少 `\)`）
  /// 5. 過度跳脫 `\\` → `\`
  /// 6. 基礎清理
  /// 7. 根據 Gemini prompt 規則驗證和修復 LaTeX 格式
  static String ultimatePreprocess(String content) {
    String processed = content;

    // ========================================
    // 第 0 步：處理 \n 變為 1n 的問題
    // ========================================
    // 直接將 `1n` 替換為換行，這是最直接的修復
    // 這可能是之前的處理錯誤導致的：`\n` 被錯誤地變成了 `1n`
    processed = processed.replaceAll('1n', '\n');

    // ========================================
    // 第一步：處理換行用的反斜線
    // ========================================
    // 移除行尾的 `\` (後面可能跟著換行或空白)
    processed = processed.replaceAll(RegExp(r'\\\s*\n'), '\n');

    // 移除獨立成行的 `\`
    processed =
        processed.replaceAll(RegExp(r'^\s*\\\s*$', multiLine: true), '');

    // 移除句末標點後面的 `\` (例如：「結果為 2。\」)，改為換行
    processed =
        processed.replaceAll(RegExp(r'([。，、；：！？])\s*\\\s*[\s\n]'), r'$1\n');

    // ========================================
    // 第二步：處理雙重括號 ((...))
    // ========================================
    // 處理 `(( ... ))` 格式（有空格）
    processed = processed.replaceAllMapped(
      RegExp(r'\(\( (.*?) \)\)'),
      (match) => r'\(' + (match.group(1) ?? '') + r'\)',
    );
    // 處理 `((...))` 格式（無空格）
    processed = processed.replaceAllMapped(
      RegExp(r'\(\(([^)]+)\)\)'),
      (match) => r'\(' + (match.group(1) ?? '') + r'\)',
    );

    // ========================================
    // 第三步：標準化 LaTeX 分隔符
    // ========================================
    // 先處理 `$$...$$` 區塊公式，避免與 `$...$` 混淆
    processed = processed.replaceAllMapped(
      RegExp(r'\$\$((?:\\.|[^$])*?)\$\$'),
      (match) => r'\[' + (match.group(1) ?? '') + r'\]',
    );

    // 將 `$...$` 替換為 `\(...\)`
    final dollarRegex = RegExp(r"\$((?:\\.|[^$])*?)\$(?!\$)");
    processed = processed.replaceAllMapped(dollarRegex, (match) {
      return r'\(' + (match.group(1) ?? '') + r'\)';
    });

    // ========================================
    // 第四步：修復不完整的 LaTeX 公式 (啟發式)
    // ========================================
    // 尋找以 `\(` 開頭，但該行沒有 `\)` 的情況，並在行尾補上
    processed = processed.split('\n').map((line) {
      if (line.contains(r'\(') && !line.contains(r'\)')) {
        // 如果這行有 `\(` 但沒有 `\)`，在行尾補上 ` \)`
        return line + r' \)';
      }
      return line;
    }).join('\n');

    // ========================================
    // 第五步：修復 LaTeX 命令問題
    // ========================================
    // 5.0 先修復常見的截斷錯誤（rac{ → \frac{，這是最高優先級的修復）
    // 這可能是因為第一步的反斜線處理錯誤地移除了 \frac 的第一個字符
    processed = processed.replaceAllMapped(
      RegExp(r'(?<!\\)\brac\{'),
      (match) => r'\frac{',
    );

    // 5.1 修復缺少反斜線的 LaTeX 命令（例如：sqrt{ → \sqrt{）
    // 這可能是因為某些處理步驟錯誤地移除了反斜線
    final commonLatexCommands = [
      'frac',
      'sqrt',
      'sum',
      'int',
      'lim',
      'alpha',
      'beta',
      'gamma',
      'delta',
      'pi',
      'theta',
      'phi',
      'omega',
      'sin',
      'cos',
      'tan',
      'log',
      'ln',
      'exp',
      'cdot',
      'times',
      'div',
      'pm',
      'mp',
      'leq',
      'geq',
      'neq',
      'approx',
      'rightarrow',
      'leftarrow',
      'leftrightarrow',
      'infty',
      'partial',
    ];
    for (final cmd in commonLatexCommands) {
      // 匹配在 LaTeX 分隔符內缺少反斜線的命令：sqrt{ → \sqrt{
      // 但要避免在已經有反斜線的情況下重複添加
      processed = processed.replaceAllMapped(
        RegExp(r'(?<!\\)\b(' + cmd + r')\{'),
        (match) => '\\${match.group(1)}{',
      );
      // 匹配在括號或其他上下文中缺少反斜線的命令
      processed = processed.replaceAllMapped(
        RegExp(r'(?<!\\)\b(' + cmd + r')(?=\s|$|[,\.;\)\]])'),
        (match) => '\\${match.group(1)}',
      );
    }

    // 5.2 修復過度跳脫（在修復缺少反斜線之後）
    // 先修復連續三個或更多反斜線的情況：\\\\\ → \\
    processed = processed.replaceAll(RegExp(r'\\\\\\+'), r'\\');

    // 5.3 只將明確的雙反斜線（在非 LaTeX 命令位置）替換為單反斜線
    // 但要避免破壞正確的轉義，只在特定情況下替換
    // 如果 `\\` 後面跟著非標準 JSON 轉義字符，將其轉為單反斜線
    processed = processed.replaceAllMapped(
      RegExp(r'\\(\\[^"\\/bfnrtu\{])'),
      (match) => match.group(1) ?? '',
    );

    // 5.4 最後，修復剩餘的明顯雙反斜線錯誤（但要小心）
    // 只在非 LaTeX 命令位置進行替換
    processed = processed.replaceAllMapped(
      RegExp(r'(?<!\\[a-zA-Z])\\(\\[a-zA-Z])'),
      (match) => match.group(1) ?? '',
    );

    // ========================================
    // 第六步：基礎清理
    // ========================================
    processed = _sanitizeInput(processed);

    // ========================================
    // 第 6.5 步：包裹裸露的 LaTeX 指令（核心修復）
    // ========================================
    // Gemini 有時不遵守 prompt 規則，回傳沒有 \( \) 包裹的 LaTeX
    // 例如："\frac{1+17}{2}" 應該變成 "\(\frac{1+17}{2}\)"
    // 放在第五步（修復反斜線）之後，確保 frac{ → \frac{ 已被處理
    // 放在第七步（驗證格式）之前，讓驗證步驟能檢查新增的 \( \) 配對
    processed = wrapBareLatexCommands(processed);

    // ========================================
    // 第七步：根據 Gemini prompt 規則驗證和修復 LaTeX 格式
    // ========================================
    processed = LatexHelper.validateAndFixLatexFormat(processed);

    return processed;
  }

  /// 常規清理函式：處理常見的髒資料問題
  static String _sanitizeInput(String input) {
    return input
        // 移除控制字元（ASCII 和 C1），保留 \n 和 \r
        .replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'[\u0080-\u009F]'), '')
        // 處理 literal \n（字串中的 \n 而非換行符）
        // ⚠️ 使用 regex 確保不會破壞 \neq, \nu, \nabla 等以 \n 開頭的 LaTeX 指令
        // 只匹配 \n 後面不是字母的情況（即不是 LaTeX 指令的一部分）
        .replaceAll(RegExp(r'\\n(?![a-zA-Z])'), '\n')
        // 移除不可見字元
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        // 將連續多個換行合併為兩個（避免過多空白）
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}

/// LaTeX 文字渲染組件（使用 gpt_markdown 渲染）
/// 原生支援 Markdown + 文字 + LaTeX 混合內容
/// 自動處理 \( ... \) 和 \[ ... \] 格式的 LaTeX 公式
///
/// 渲染策略：
/// - 純文字行 → GptMarkdown（自動換行）
/// - 含 LaTeX 公式行 → FittedBox(scaleDown) 自動縮放至螢幕寬度
///   → 點擊可彈出 BottomSheet 顯示原尺寸可捲動公式
class LatexText extends StatelessWidget {
  final String text;
  final double? fontSize;
  final Color? textColor;
  final double? lineHeight;

  const LatexText({
    super.key,
    required this.text,
    this.fontSize,
    this.textColor,
    this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    final processedText = LatexHelper.ultimatePreprocess(text);

    final baseStyle = Theme.of(context).textTheme.bodyLarge;
    final textStyle = AppFonts.resolve(
      (baseStyle ?? const TextStyle()).copyWith(
        fontSize: fontSize ?? baseStyle?.fontSize ?? 15,
        color: textColor ?? baseStyle?.color ?? Colors.black,
        height: lineHeight ?? baseStyle?.height,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        final lines = processedText.split('\n');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < lines.length; i++) ...[
              _buildDisplayLine(context, lines[i], textStyle, viewportWidth),
              if (i < lines.length - 1) const SizedBox(height: 4),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDisplayLine(
    BuildContext context,
    String line,
    TextStyle textStyle,
    double viewportWidth,
  ) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return SizedBox(height: (textStyle.fontSize ?? 15) * 0.6);
    }

    if (_isStandaloneFormula(trimmed)) {
      return GestureDetector(
        onTap: () => _showFormulaDetail(context, trimmed, textStyle),
        child: SizedBox(
          width: viewportWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: GptMarkdown(trimmed, style: textStyle),
          ),
        ),
      );
    }

    // 文字為主的行：先將 inline 數學轉成 Unicode 純文字，
    // 避免 GptMarkdown 觸發 flutter_math_fork 造成 RenderLine overflow
    final safeText = _flattenInlineMath(trimmed);
    return GptMarkdown(safeText, style: textStyle);
  }

  /// 將 inline LaTeX 公式（\(...\) 和 $...$）轉成 Unicode 可讀文字，
  /// 讓 GptMarkdown 以普通文字渲染而非調用 flutter_math_fork
  static String _flattenInlineMath(String text) {
    var result = text.replaceAllMapped(
      RegExp(r'\\\((.+?)\\\)'),
      (m) => LatexHelper.toReadableText(m.group(1) ?? '',
          fallback: m.group(0) ?? ''),
    );
    result = result.replaceAllMapped(
      RegExp(r'(?<!\$)\$(?!\$)(.+?)(?<!\$)\$(?!\$)'),
      (m) => LatexHelper.toReadableText(m.group(1) ?? '',
          fallback: m.group(0) ?? ''),
    );
    // display math \[...\] 也轉換
    result = result.replaceAllMapped(
      RegExp(r'\\\[(.+?)\\\]'),
      (m) => LatexHelper.toReadableText(m.group(1) ?? '',
          fallback: m.group(0) ?? ''),
    );
    return result;
  }

  static final _latexCommandPattern = RegExp(
    r'\\\(|\\\)|\\\[|\\\]|\\frac|\\sqrt|\\sum|\\int|\\overline|\\vec|'
    r'\\angle|\\begin|\\end|\\pm|\\times|\\div|\\cdot|\\leq|\\geq|'
    r'\\neq|\\text\{|\\mathrm\{|\\mathbf\{|\\left|\\right',
  );

  static final _cjkPattern = RegExp(r'[\u4E00-\u9FFF\u3000-\u303F]');

  bool _isStandaloneFormula(String line) {
    if (!_latexCommandPattern.hasMatch(line)) return false;

    // 含有大量中日韓文字 → 文字段落（帶 inline 數學），應正常換行
    final cjkCount = _cjkPattern.allMatches(line).length;
    if (cjkCount > 6) return false;

    return true;
  }

  void _showFormulaDetail(
    BuildContext context,
    String formula,
    TextStyle textStyle,
  ) {
    final enlargedStyle = textStyle.copyWith(
      fontSize: (textStyle.fontSize ?? 15) + 4,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.functions, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '公式詳情',
                    style: textStyle.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '← 可左右滑動 →',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: GptMarkdown(formula, style: enlargedStyle),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// 帶錯誤處理的安全版本（進階使用）
/// 當渲染失敗時提供 fallback
class SafeMathTextWidget extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Widget Function(String rawText)? onError;

  const SafeMathTextWidget({
    super.key,
    required this.text,
    this.style,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    // 執行終極前處理：多階段清洗和轉換（統一使用 LatexHelper）
    final processedText = LatexHelper.ultimatePreprocess(text);

    // 使用 try-catch 包裝，確保渲染失敗時有 fallback
    try {
      final resolvedStyle = AppFonts.resolve(
        style ?? Theme.of(context).textTheme.bodyLarge,
      );

      return SelectionArea(
        child: ClipRect(
          child: GptMarkdown(
            processedText,
            style: resolvedStyle,
          ),
        ),
      );
    } catch (e) {
      debugPrint("⚠️ GptMarkdown 渲染失敗: $e");
      // 渲染失敗時的 fallback
      if (onError != null) {
        return onError!(text);
      }
      // 預設 fallback：顯示純文字（移除 LaTeX 標記）
      return SelectableText(
        LatexHelper.toReadableText(text),
        style: AppFonts.resolve(style ?? Theme.of(context).textTheme.bodyLarge),
      );
    }
  }
}
