import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/models/mistake.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/home_mesh_reference_colors.dart';
import '../../../core/utils/app_ux.dart';
import '../../../core/utils/latex_helper.dart';
import '../../../core/widgets/feature_setup_chrome.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_image_viewer.dart';
import '../../mistakes/providers/mistakes_provider.dart';
import '../../solver/presentation/solver_page.dart';

enum _MockExamStage {
  setup,
  running,
  result,
}

enum _SelfAssessment {
  know,
  unsure,
  dontKnow,
}

class MockExamPage extends ConsumerStatefulWidget {
  const MockExamPage({super.key});

  @override
  ConsumerState<MockExamPage> createState() => _MockExamPageState();
}

class _MockExamPageState extends ConsumerState<MockExamPage> {
  /// 與首頁六張小卡同序；頂部橫幅用 [HomeCompactCardPalette.compactGradientByIndex]。
  late final int _setupHeroPaletteIndex;

  _MockExamStage _stage = _MockExamStage.setup;
  String _selectedSubject = '全部';
  int _questionCount = 5;
  int _durationMinutes = 15;
  bool _dueOnly = false;
  bool _prioritizeWeakSpots = true;
  bool _shuffleQuestions = true;

  List<Mistake> _examQueue = const [];
  final Map<int, _SelfAssessment> _answers = <int, _SelfAssessment>{};
  int _currentIndex = 0;
  int _remainingSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _setupHeroPaletteIndex =
        Random().nextInt(HomeCompactCardPalette.solidColors.length);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mistakesAsync = ref.watch(allMistakesRawProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_titleForStage()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: mistakesAsync.when(
        data: (mistakes) {
          if (mistakes.isEmpty) {
            return const _EmptyExamState();
          }

          switch (_stage) {
            case _MockExamStage.setup:
              return _buildSetup(mistakes);
            case _MockExamStage.running:
              return _buildExam();
            case _MockExamStage.result:
              return _buildResult();
          }
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('載入模擬測驗資料失敗：$error'),
          ),
        ),
      ),
    );
  }

  String _titleForStage() {
    switch (_stage) {
      case _MockExamStage.setup:
        return '自訂模擬測驗';
      case _MockExamStage.running:
        return '作答中';
      case _MockExamStage.result:
        return '測驗結果';
    }
  }

  Widget _buildSetup(List<Mistake> mistakes) {
    final subjects = <String>{'全部', ...mistakes.map((item) => item.subject)}
      ..removeWhere((item) => item.trim().isEmpty);
    final availableCount = _buildCandidates(mistakes).length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FeatureSetupHero(
          paletteIndex: _setupHeroPaletteIndex,
          title: '把錯題庫變成一場小考',
          subtitle:
              '依科目、題數與時間快速組卷，先用自我評估找出會與不會，再點進詳解補洞。',
        ),
        const SizedBox(height: 24),
        const FeatureSectionTitle('出題範圍'),
        const SizedBox(height: 12),
        PremiumCard(
          backgroundOpacity: 0.52,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subjects.toList().asMap().entries.map(
                    (e) => FeaturePaletteChipButton(
                      sectionIndex: 0,
                      chipIndex: e.key,
                      label: e.value,
                      selected: _selectedSubject == e.value,
                      onTap: () => setState(() => _selectedSubject = e.value),
                    ),
                  ).toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const FeatureSectionTitle('題數'),
        const SizedBox(height: 12),
        PremiumCard(
          backgroundOpacity: 0.52,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [5, 10, 15, 20]
                  .asMap()
                  .entries
                  .map(
                    (e) => FeaturePaletteChipButton(
                      sectionIndex: 1,
                      chipIndex: e.key,
                      label: '${e.value} 題',
                      selected: _questionCount == e.value,
                      onTap: () => setState(() => _questionCount = e.value),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const FeatureSectionTitle('時間限制'),
        const SizedBox(height: 12),
        PremiumCard(
          backgroundOpacity: 0.52,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [10, 15, 20, 30]
                  .asMap()
                  .entries
                  .map(
                    (e) => FeaturePaletteChipButton(
                      sectionIndex: 2,
                      chipIndex: e.key,
                      label: '${e.value} 分鐘',
                      selected: _durationMinutes == e.value,
                      onTap: () => setState(() => _durationMinutes = e.value),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const FeatureSectionTitle('進階條件'),
        const SizedBox(height: 12),
        PremiumCard(
          backgroundOpacity: 0.52,
          child: Column(
            children: [
              SwitchListTile(
                value: _dueOnly,
                title: const Text('只出待複習題'),
                subtitle: const Text('優先考你現在最該回頭看的題目'),
                onChanged: (value) => setState(() => _dueOnly = value),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: _prioritizeWeakSpots,
                title: const Text('優先弱點章節'),
                subtitle: const Text('先把掌握度低、重複卡住的題目排前面'),
                onChanged: (value) =>
                    setState(() => _prioritizeWeakSpots = value),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: _shuffleQuestions,
                title: const Text('隨機順序'),
                subtitle: const Text('打散題目順序，避免只背印象'),
                onChanged: (value) => setState(() => _shuffleQuestions = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PremiumCard(
          backgroundOpacity: 0.52,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(
                  Icons.fact_check_rounded,
                  color: Color(0xFF007AFF),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    availableCount == 0
                        ? '目前沒有符合條件的題目，試著放寬範圍。'
                        : '可組出 $availableCount 題，這次會抽出 ${min(_questionCount, availableCount)} 題。',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: availableCount == 0 ? null : () => _startExam(mistakes),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.textPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Text('開始測驗'),
        ),
      ],
    );
  }

  Widget _buildExam() {
    if (_examQueue.isEmpty) {
      return const Center(child: Text('目前沒有題目可作答'));
    }

    final mistake = _examQueue[_currentIndex];
    final progress = (_currentIndex + 1) / _examQueue.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    '第 ${_currentIndex + 1} / ${_examQueue.length} 題',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _formatSeconds(_remainingSeconds),
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF5B6CFF),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              PremiumCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TagPill(
                            label: mistake.subject,
                            color: const Color(0xFFFF8A00),
                          ),
                          _TagPill(
                            label: mistake.category,
                            color: const Color(0xFF007AFF),
                          ),
                        ],
                      ),
                      if (mistake.imagePath.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Hero(
                          tag: 'mock_exam_image_${mistake.id ?? _currentIndex}',
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 260),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                children: [
                                  AspectRatio(
                                    aspectRatio: 4 / 3,
                                    child: InteractiveViewer(
                                      minScale: 1,
                                      maxScale: 4,
                                      panEnabled: true,
                                      scaleEnabled: true,
                                      child: Center(
                                        child: Image.file(
                                          File(mistake.imagePath),
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                            Icons.image_not_supported,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 10,
                                    bottom: 10,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.55,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.gesture_rounded,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                '雙指縮放',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () {
                                            AppUX.feedbackClick();
                                            Navigator.of(context).push(
                                              AppUX.fadeRoute(
                                                PremiumImageViewer(
                                                  imagePath: mistake.imagePath,
                                                  heroTag:
                                                      'mock_exam_image_${mistake.id ?? _currentIndex}',
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.55,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.zoom_out_map_rounded,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  '全螢幕',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        LatexHelper.toReadableText(
                          mistake.title,
                          fallback: '未命名題目',
                        ),
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.7,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '先自己想，再選最接近你現在狀態的答案。',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AssessmentButton(
                  label: '這題我會',
                  subtitle: '可以自己做出來',
                  color: const Color(0xFF22C55E),
                  onTap: () => _answerCurrent(_SelfAssessment.know),
                ),
                const SizedBox(height: 10),
                _AssessmentButton(
                  label: '不太穩',
                  subtitle: '有想法，但容易卡住',
                  color: const Color(0xFFF59E0B),
                  onTap: () => _answerCurrent(_SelfAssessment.unsure),
                ),
                const SizedBox(height: 10),
                _AssessmentButton(
                  label: '我不會',
                  subtitle: '需要回去看詳解',
                  color: const Color(0xFFE11D48),
                  onTap: () => _answerCurrent(_SelfAssessment.dontKnow),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final total = _examQueue.length;
    final knowCount =
        _answers.values.where((item) => item == _SelfAssessment.know).length;
    final unsureCount =
        _answers.values.where((item) => item == _SelfAssessment.unsure).length;
    final dontKnowCount = _answers.values
        .where((item) => item == _SelfAssessment.dontKnow)
        .length;
    final readiness = total == 0
        ? 0
        : (((knowCount * 2) + unsureCount) / (total * 2) * 100).round();
    final timeUsedSeconds = max(
      0,
      (_durationMinutes * 60) - _remainingSeconds,
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF111827), Color(0xFF374151)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '準備度 $readiness 分',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _resultSummary(readiness, dontKnowCount),
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _ResultMetricCard(
              label: '會做',
              value: '$knowCount 題',
              color: const Color(0xFF22C55E),
            ),
            _ResultMetricCard(
              label: '不太穩',
              value: '$unsureCount 題',
              color: const Color(0xFFF59E0B),
            ),
            _ResultMetricCard(
              label: '不會',
              value: '$dontKnowCount 題',
              color: const Color(0xFFE11D48),
            ),
            _ResultMetricCard(
              label: '耗時',
              value: _formatSeconds(timeUsedSeconds),
              color: const Color(0xFF007AFF),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const FeatureSectionTitle('逐題回看'),
        const SizedBox(height: 12),
        ..._examQueue.asMap().entries.map((entry) {
          final index = entry.key;
          final mistake = entry.value;
          final assessment = _answers[mistake.id] ?? _SelfAssessment.unsure;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PremiumCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '第 ${index + 1} 題',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        _ResultBadge(assessment: assessment),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      LatexHelper.toReadableText(
                        mistake.title,
                        fallback: '未命名題目',
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        height: 1.6,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => _openSolverPage(mistake),
                      child: const Text('查看詳解'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _resetToSetup,
                child: const Text('重新組卷'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _restartSameExam,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('再做一次'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Mistake> _buildCandidates(List<Mistake> mistakes) {
    final now = DateTime.now();
    final filtered = mistakes.where((mistake) {
      if (_selectedSubject != '全部' && mistake.subject != _selectedSubject) {
        return false;
      }
      if (_dueOnly) {
        final nextReviewAt = mistake.nextReviewAt;
        return nextReviewAt == null || !nextReviewAt.isAfter(now);
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      if (_prioritizeWeakSpots) {
        final masteryCompare = a.masteryLevel.compareTo(b.masteryLevel);
        if (masteryCompare != 0) return masteryCompare;
        final reviewCompare = a.reviewCount.compareTo(b.reviewCount);
        if (reviewCompare != 0) return reviewCompare;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    if (_shuffleQuestions && filtered.length > 1) {
      final poolSize =
          min(filtered.length, max(_questionCount * 2, _questionCount));
      final pool = filtered.take(poolSize).toList()..shuffle(Random());
      final rest = filtered.skip(poolSize);
      return [...pool, ...rest];
    }

    return filtered;
  }

  void _startExam(List<Mistake> mistakes) {
    final candidates = _buildCandidates(mistakes);
    if (candidates.isEmpty) {
      AppUX.showSnackBar(context, '目前沒有符合條件的題目', isError: true);
      return;
    }

    _timer?.cancel();
    setState(() {
      _stage = _MockExamStage.running;
      _examQueue = candidates.take(_questionCount).toList();
      _answers.clear();
      _currentIndex = 0;
      _remainingSeconds = _durationMinutes * 60;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _finishExam();
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  void _answerCurrent(_SelfAssessment assessment) {
    final currentMistake = _examQueue[_currentIndex];
    setState(() {
      _answers[currentMistake.id!] = assessment;
      if (_currentIndex >= _examQueue.length - 1) {
        _finishExam();
      } else {
        _currentIndex += 1;
      }
    });
  }

  void _finishExam() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _stage = _MockExamStage.result;
    });
  }

  void _resetToSetup() {
    _timer?.cancel();
    setState(() {
      _stage = _MockExamStage.setup;
      _examQueue = const [];
      _answers.clear();
      _currentIndex = 0;
      _remainingSeconds = 0;
    });
  }

  void _restartSameExam() {
    if (_examQueue.isEmpty) {
      _resetToSetup();
      return;
    }
    _timer?.cancel();
    setState(() {
      _stage = _MockExamStage.running;
      _answers.clear();
      _currentIndex = 0;
      _remainingSeconds = _durationMinutes * 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _finishExam();
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  Future<void> _openSolverPage(Mistake mistake) async {
    final imageFile =
        mistake.imagePath.isNotEmpty ? File(mistake.imagePath) : null;
    await Navigator.of(context).push(
      AppUX.fadeRoute(
        SolverPage(
          originalImage: imageFile,
          initialLatex: mistake.title,
          isFromMistakes: true,
          savedSolutions: mistake.solutions,
          subject: mistake.subject,
          category: mistake.category,
          chapter: mistake.resolvedChapter,
          keyConcepts: mistake.resolvedKeyConcepts,
          mistakeId: mistake.id,
        ),
      ),
    );
  }

  String _formatSeconds(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _resultSummary(int readiness, int dontKnowCount) {
    if (readiness >= 80) {
      return '這份卷子的掌握度很不錯，保持複習節奏就能更穩。';
    }
    if (dontKnowCount >= 3) {
      return '這次有幾題明顯卡住，建議先點進詳解，把不會的觀念各補一輪。';
    }
    return '整體有基礎，但還有幾題不夠穩，回看解析後再做一次會更有效。';
  }
}

class _AssessmentButton extends StatelessWidget {
  const _AssessmentButton({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.chevron_right_rounded, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ResultMetricCard extends StatelessWidget {
  const _ResultMetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultBadge extends StatelessWidget {
  const _ResultBadge({required this.assessment});

  final _SelfAssessment assessment;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;

    switch (assessment) {
      case _SelfAssessment.know:
        label = '會做';
        color = const Color(0xFF22C55E);
        break;
      case _SelfAssessment.unsure:
        label = '不太穩';
        color = const Color(0xFFF59E0B);
        break;
      case _SelfAssessment.dontKnow:
        label = '不會';
        color = const Color(0xFFE11D48);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyExamState extends StatelessWidget {
  const _EmptyExamState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: 16),
            Text(
              '還沒有題目可以組卷',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '先把錯題存進題庫，這裡就能快速抽題，幫你做一場自己的小考。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
