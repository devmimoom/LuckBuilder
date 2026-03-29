import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_ux.dart';
import '../../../core/utils/latex_helper.dart';

class GlyphTestPage extends StatelessWidget {
  const GlyphTestPage({super.key});

  static const List<_GlyphSection> _sections = [
    _GlyphSection(
      title: '中文與標點',
      description: '先確認常用繁中字、括號與全形標點都能正常顯示。',
      samples: [
        '列印設定、我的錯題本、LuckLab',
        '（如圖）下列敘述何者正確？請選出正確答案。',
        '甲、乙、丙、丁；因為、所以、因此、但是。',
      ],
    ),
    _GlyphSection(
      title: '數學符號',
      description: '涵蓋常見四則、比較、根號、積分、集合與箭頭。',
      samples: [
        '± × ÷ ≠ ≤ ≥ ≈ ∞ π ∑ ∏ ∫ √ ∛',
        '∠ △ □ ○ ⊥ ∥ ∈ ∉ ∅ ∩ ∪ ⊂ ⊆',
        '→ ← ↑ ↓ ↔ ⇒ ⇔',
      ],
    ),
    _GlyphSection(
      title: '上下標與化學式',
      description: '這些字最容易因 fallback 不完整而出現方塊或亂碼。',
      samples: [
        'x² + y² = z²',
        'a₁ + a₂ + a₃ = 3a',
        'H₂O、CO₂、Na⁺、SO₄²⁻',
      ],
    ),
    _GlyphSection(
      title: 'LatexText 混排',
      description: '同時驗證一般文字與 LaTeX/Markdown 混排是否正常。',
      samples: [
        r'已知 \( x^2 + y^2 = z^2 \)，求 \( x \) 的值。',
        r'集合 \( A \cap B \subseteq C \)，且 \( f(x) = \frac{1}{x+1} \)。',
        r'若 \( a_n = a_1 + (n-1)d \)，則 \( S_n = \frac{n(a_1 + a_n)}{2} \)。',
      ],
      useLatexText: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('缺字測試'),
        actions: [
          IconButton(
            tooltip: '複製測試字串',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () {
              AppUX.feedbackClick();
              final payload = _sections
                  .map((section) => [
                        section.title,
                        ...section.samples,
                      ].join('\n'))
                  .join('\n\n');
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await Clipboard.setData(ClipboardData(text: payload));
                if (context.mounted) {
                  AppUX.showSnackBar(context, '已複製測試字串');
                }
              });
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              '如果這頁所有文字都正常，代表 App 內大部分 UI 已經吃到字型 fallback。若仍看到方塊、缺字或亂碼，再把那一段截圖給我，我可以針對剩餘字元補強。',
              style: TextStyle(height: 1.6),
            ),
          ),
          const SizedBox(height: 16),
          ..._sections.map((section) => _SectionCard(section: section)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final _GlyphSection section;

  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            section.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          ...section.samples.map((sample) {
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: section.useLatexText
                  ? LatexText(
                      text: sample,
                      fontSize: 16,
                      lineHeight: 1.6,
                    )
                  : Text(
                      sample,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
            );
          }),
        ],
      ),
    );
  }
}

class _GlyphSection {
  final String title;
  final String description;
  final List<String> samples;
  final bool useLatexText;

  const _GlyphSection({
    required this.title,
    required this.description,
    required this.samples,
    this.useLatexText = false,
  });
}
