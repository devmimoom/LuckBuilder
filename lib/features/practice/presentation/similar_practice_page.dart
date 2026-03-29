import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/gemini_service.dart';
import '../../../core/services/image_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/home_mesh_reference_colors.dart';
import '../../../core/widgets/feature_setup_chrome.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/utils/ai_practice_image_helper.dart';
import '../../../core/utils/app_ux.dart';
import '../../../core/utils/latex_helper.dart';
import '../../../core/utils/paywall_gate.dart';
import '../../camera/presentation/multi_crop_screen.dart';
import '../../camera/utils/crop_image_helper.dart';
import '../../mistakes/providers/mistakes_provider.dart';
import '../../subscription/providers/feature_trial_provider.dart';

class SimilarPracticePage extends ConsumerStatefulWidget {
  const SimilarPracticePage({
    super.key,
    this.initialQuestionText,
    this.initialImagePath,
  });

  final String? initialQuestionText;
  final String? initialImagePath;

  @override
  ConsumerState<SimilarPracticePage> createState() =>
      _SimilarPracticePageState();
}

class _SimilarPracticePageState extends ConsumerState<SimilarPracticePage> {
  final TextEditingController _questionController = TextEditingController();

  File? _sourceImage;
  _SimilarPracticeResult? _result;
  bool _isGenerating = false;
  bool _isRecognizingImage = false;
  bool _isSavingToMistakes = false;
  bool _hasSavedCurrentResult = false;
  bool _showAnswer = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final initialQuestionText = widget.initialQuestionText?.trim();
    if (initialQuestionText != null && initialQuestionText.isNotEmpty) {
      _questionController.text = initialQuestionText;
    }

    final initialImagePath = widget.initialImagePath?.trim();
    if (initialImagePath != null && initialImagePath.isNotEmpty) {
      _sourceImage = File(initialImagePath);
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('AI 相似題練習'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FeatureSetupHero(
              paletteIndex: HomeFeatureCardPaletteIndex.similarPractice,
              title: '輸入一題錯題，AI 幫你出一題相似練習',
              subtitle:
                  '你可以直接輸入題目，也可以用拍照或相簿匯入，再用和拍照解題相同的框選方式選出題目範圍。',
            ),
            const SizedBox(height: 24),
            _buildInputCard(),
            const SizedBox(height: 16),
            _buildGenerateButton(),
            if (_isRecognizingImage) ...[
              const SizedBox(height: 16),
              _buildRecognizingImageCard(),
            ],
            if (_isGenerating) ...[
              const SizedBox(height: 16),
              _buildLoadingCard(),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(_errorMessage!),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              _buildResultCard(_result!),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return PremiumCard(
      backgroundOpacity: 0.52,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FeatureSectionTitle('輸入錯題'),
          const SizedBox(height: 8),
          const Text(
            '輸入文字可直接出題；如果使用圖片，系統會先 OCR 辨識題目，你也可以再手動修正。',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _questionController,
            minLines: 6,
            maxLines: 10,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: '例如：已知 \\(2x + 5 = 17\\)，求 \\(x\\) 的值。',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _isRecognizingImage || _isGenerating
                    ? null
                    : () => _pickImage(fromCamera: true),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('拍照輔助'),
              ),
              OutlinedButton.icon(
                onPressed: _isRecognizingImage || _isGenerating
                    ? null
                    : () => _pickImage(fromCamera: false),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('相簿輔助'),
              ),
              if (_sourceImage != null)
                OutlinedButton.icon(
                  onPressed: () {
                    AppUX.feedbackClick();
                    setState(() {
                      _sourceImage = null;
                    });
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('移除圖片'),
                ),
            ],
          ),
          if (_sourceImage != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                _sourceImage!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '已匯入框選後的題目圖片，AI 會用它輔助理解來源題目。',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: const Text(
                '圖片的練習題功能開發中',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _isGenerating ? null : _generatePractice,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(_isGenerating ? 'AI 出題中...' : '產生相似題'),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return PremiumCard(
      backgroundOpacity: 0.52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI 正在根據這題幫你生成一題不需要圖片的相似練習題...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (_sourceImage != null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '圖片的練習題功能開發中',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecognizingImageCard() {
    return const PremiumCard(
      backgroundOpacity: 0.52,
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'AI 正在辨識圖片中的題目文字，完成後會自動帶入輸入框。',
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return PremiumCard(
      backgroundOpacity: 0.52,
      child: Text(
        message,
        style: TextStyle(
          color: Colors.red.shade700,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildResultCard(_SimilarPracticeResult result) {
    return PremiumCard(
      backgroundOpacity: 0.52,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI 相似題',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (result.gradeLevel.isNotEmpty ||
                        result.chapter.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (result.gradeLevel.isNotEmpty) result.gradeLevel,
                          if (result.chapter.isNotEmpty) result.chapter,
                        ].join(' • '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _buildInfoTag(result.difficultyLabel),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (result.subject.isNotEmpty)
                _buildMetaTag(result.subject, const Color(0xFFFF9800)),
              if (result.category.isNotEmpty)
                _buildMetaTag(result.category, const Color(0xFF2196F3)),
            ],
          ),
          const SizedBox(height: 14),
          LatexText(
            text: LatexHelper.cleanOcrText(result.questionText),
            fontSize: 15,
            lineHeight: 1.75,
          ),
          if (result.keyConcepts.isNotEmpty || result.keyPoint.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '核心觀念',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...result.keyConcepts.map(
                        (concept) => _buildConceptTag(concept),
                      ),
                      if (result.keyConcepts.isEmpty &&
                          result.keyPoint.isNotEmpty)
                        _buildConceptTag(result.keyPoint),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSavingToMistakes || _hasSavedCurrentResult
                      ? null
                      : _saveToMistakes,
                  icon: Icon(
                    _hasSavedCurrentResult
                        ? Icons.check_circle
                        : Icons.bookmark_add_outlined,
                  ),
                  label: Text(
                    _hasSavedCurrentResult
                        ? '已加入錯題庫'
                        : (_isSavingToMistakes ? '儲存中...' : '加入錯題庫'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    AppUX.feedbackClick();
                    setState(() {
                      _showAnswer = !_showAnswer;
                    });
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_showAnswer ? '收起答案' : '看答案與解析'),
                ),
              ),
            ],
          ),
          if (_isSavingToMistakes) ...[
            const SizedBox(height: 10),
            const Text(
              '正在建立 AI 練習題卡片並存入錯題庫...',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          if (!_showAnswer) const SizedBox.shrink(),
          if (_showAnswer) ...[
            const Divider(height: 28),
            const Text(
              '答案',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            LatexText(
              text: LatexHelper.cleanOcrText(result.answer),
              fontSize: 14,
              lineHeight: 1.7,
            ),
            const SizedBox(height: 16),
            const Text(
              '解析',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            LatexText(
              text: LatexHelper.cleanOcrText(result.explanation),
              fontSize: 14,
              lineHeight: 1.8,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildConceptTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1976D2),
        ),
      ),
    );
  }

  Widget _buildInfoTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF007AFF),
        ),
      ),
    );
  }

  Future<void> _pickImage({required bool fromCamera}) async {
    AppUX.feedbackClick();
    final image = await ImageService().pickAndCompressImage(
      context,
      fromCamera: fromCamera,
    );
    if (image == null || !mounted) return;

    final cropResult = await Navigator.of(context).push<CropImageResult>(
      AppUX.fadeRoute(
        MultiCropScreen(
          imageFile: image,
          completionMode: MultiCropCompletionMode.returnCrops,
          confirmButtonText: '匯入題目',
        ),
      ),
    );

    if (!mounted || cropResult == null || cropResult.cropPaths.isEmpty) {
      return;
    }

    final cropPath = cropResult.firstCropPath;
    if (cropPath == null) return;

    if (cropResult.cropPaths.length > 1) {
      AppUX.showSnackBar(context, '已匯入第一個框選區塊，你可以再手動調整文字');
    }

    setState(() {
      _sourceImage = File(cropPath);
      _result = null;
      _errorMessage = null;
      _showAnswer = false;
      _hasSavedCurrentResult = false;
    });

    await _recognizeImageQuestion(File(cropPath));
  }

  Future<void> _recognizeImageQuestion(File imageFile) async {
    setState(() {
      _isRecognizingImage = true;
      _errorMessage = null;
    });

    try {
      final recognizedText = await GeminiService().recognizeImage(imageFile);
      if (!mounted) return;

      if (recognizedText == null || recognizedText.trim().isEmpty) {
        AppUX.showSnackBar(context, '圖片辨識失敗，請手動輸入題目', isError: true);
        return;
      }

      setState(() {
        _questionController.text = recognizedText.trim();
      });
      AppUX.feedbackSuccess();
      AppUX.showSnackBar(context, '已自動帶入題目文字，可再手動修改');
    } finally {
      if (mounted) {
        setState(() {
          _isRecognizingImage = false;
        });
      }
    }
  }

  Future<void> _generatePractice() async {
    final questionText = _questionController.text.trim();
    if (questionText.isEmpty) {
      AppUX.showSnackBar(context, '請先輸入錯題內容', isError: true);
      return;
    }

    if (!await PaywallGate.consumeTrialIfNeeded(
      context,
      ref,
      TrialFeature.similarPractice,
    )) {
      return;
    }

    AppUX.feedbackClick();
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _result = null;
      _showAnswer = false;
      _hasSavedCurrentResult = false;
    });

    try {
      final rawResult = await GeminiService().generateSimilarPracticeQuestion(
        sourceQuestionText: questionText,
        imageFile: _sourceImage,
      );

      if (!mounted) return;

      if (rawResult == null) {
        setState(() {
          _errorMessage = '這次出題失敗了，請稍後再試一次。';
        });
        return;
      }

      final parsedResult = _SimilarPracticeResult.fromMap(rawResult);
      setState(() {
        _result = parsedResult;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'AI 回傳格式異常，請調整題目描述後再試一次。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _saveToMistakes() async {
    final result = _result;
    if (result == null || _isSavingToMistakes || _hasSavedCurrentResult) return;

    AppUX.feedbackClick();
    setState(() {
      _isSavingToMistakes = true;
    });

    try {
      final placeholderImagePath =
          await AiPracticeImageHelper.createPlaceholderImage(
        subject: result.subject,
        category: result.category,
      );

      final tags = <String>[
        'AI 練習題',
        if (result.chapter.isNotEmpty) result.chapter,
        ...result.keyConcepts.take(5),
      ];

      final solutions = <String>[
        '答案：${result.answer}',
        '解析：${result.explanation}',
      ];

      await ref.read(mistakesProvider.notifier).addMistake(
            imagePath: placeholderImagePath,
            title: result.questionText,
            tags: tags,
            solutions: solutions,
            subject: result.subject.isNotEmpty ? result.subject : '其他',
            category: result.category.isNotEmpty ? result.category : '其他',
            chapter: result.chapter.isNotEmpty ? result.chapter : null,
            errorReason: 'AI 練習題',
          );

      if (!mounted) return;
      setState(() {
        _hasSavedCurrentResult = true;
      });
      AppUX.feedbackSuccess();
      AppUX.showSnackBar(context, '已加入錯題庫');
    } catch (_) {
      if (!mounted) return;
      AppUX.showSnackBar(context, '加入錯題庫失敗，請稍後再試', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSavingToMistakes = false;
        });
      }
    }
  }
}

class _SimilarPracticeResult {
  const _SimilarPracticeResult({
    required this.questionText,
    required this.answer,
    required this.explanation,
    required this.difficulty,
    required this.subject,
    required this.gradeLevel,
    required this.category,
    required this.chapter,
    required this.keyConcepts,
    required this.keyPoint,
  });

  final String questionText;
  final String answer;
  final String explanation;
  final String difficulty;
  final String subject;
  final String gradeLevel;
  final String category;
  final String chapter;
  final List<String> keyConcepts;
  final String keyPoint;

  String get difficultyLabel {
    switch (difficulty) {
      case 'easier':
        return '較簡單';
      case 'harder':
        return '較進階';
      default:
        return '同等難度';
    }
  }

  factory _SimilarPracticeResult.fromMap(Map<String, dynamic> map) {
    final questionText = (map['question_text'] ?? '').toString().trim();
    final answer = (map['answer'] ?? '').toString().trim();
    final explanation = (map['explanation'] ?? '').toString().trim();
    final difficulty = (map['difficulty'] ?? 'same').toString().trim();
    final subject = (map['subject'] ?? '').toString().trim();
    final gradeLevel = (map['grade_level'] ?? '').toString().trim();
    final category = (map['category'] ?? '').toString().trim();
    final chapter = (map['chapter'] ?? '').toString().trim();
    final keyConcepts = ((map['key_concepts'] as List<dynamic>?) ?? const [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final keyPoint = (map['key_point'] ?? '').toString().trim();

    if (questionText.isEmpty || answer.isEmpty || explanation.isEmpty) {
      throw const FormatException('Missing required fields');
    }

    return _SimilarPracticeResult(
      questionText: questionText,
      answer: answer,
      explanation: explanation,
      difficulty: difficulty,
      subject: subject,
      gradeLevel: gradeLevel,
      category: category,
      chapter: chapter,
      keyConcepts: keyConcepts,
      keyPoint: keyPoint,
    );
  }
}
