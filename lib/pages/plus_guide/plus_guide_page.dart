import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bubble_library/models/push_config.dart';
import '../../bubble_library/models/user_library.dart';
import '../../bubble_library/notifications/notification_service.dart';
import '../../bubble_library/notifications/push_orchestrator.dart';
import '../../bubble_library/providers/providers.dart';
import '../../data/models.dart';
import '../../localization/app_language.dart';
import '../../localization/app_language_provider.dart';
import '../../localization/app_strings.dart';
import '../../localization/bilingual_text.dart';
import '../../providers/nav_providers.dart';
import '../../providers/v2_providers.dart';
import '../../theme/app_tokens.dart';
import 'plus_guide_state.dart';

// ─────────────────────────────────────────────
// Layout constants
// ─────────────────────────────────────────────

const _kCardMaxWidth = 420.0;
const _kCardOuterH = 16.0;
const _kCardOuterV = 8.0;
const _kCardOuterBottom = 16.0;
const _kCardInnerPadding = 24.0;
const _kSectionSpacing = 20.0;
const _kButtonMinHeight = 48.0;
const _kButtonSpacing = 12.0;
const _kWideBreakpoint = 600.0;
const _kProductListMaxHeight = 260.0;

const _kAllSlots = [
  '7-9', '9-11', '11-13', '13-15', '15-17', '17-19', '19-21', '21-23',
];
const _kSlotLabels = {
  '7-9': '07–09',  '9-11': '09–11', '11-13': '11–13', '13-15': '13–15',
  '15-17': '15–17', '17-19': '17–19', '19-21': '19–21', '21-23': '21–23',
};

// ─────────────────────────────────────────────
// Theme-aware card colors
// ─────────────────────────────────────────────

class _GuideColors {
  final Color cardStart;
  final Color cardEnd;
  final Color cardShadow;
  final Color surface;
  final Color surfaceSelected;
  final Color accent;
  final Color accentDeep;
  final Color titleText;
  final Color bodyText;
  final Color mutedText;
  final Color positiveText;
  final Color positiveBg;
  final Color warningBg;
  final Color warningText;
  final Color chipBg;
  final Color chipBorder;

  const _GuideColors._({
    required this.cardStart,
    required this.cardEnd,
    required this.cardShadow,
    required this.surface,
    required this.surfaceSelected,
    required this.accent,
    required this.accentDeep,
    required this.titleText,
    required this.bodyText,
    required this.mutedText,
    required this.positiveText,
    required this.positiveBg,
    required this.warningBg,
    required this.warningText,
    required this.chipBg,
    required this.chipBorder,
  });

  factory _GuideColors.of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return const _GuideColors._(
        cardStart: Color(0xFF1E2236),
        cardEnd: Color(0xFF14182C),
        cardShadow: Color(0x44000000),
        surface: Color(0x1AFFFFFF),
        surfaceSelected: Color(0xFF2E3350),
        accent: Color(0xFFE8A838),
        accentDeep: Color(0xFFD49520),
        titleText: Color(0xFFEDE8DD),
        bodyText: Color(0xFF9A9484),
        mutedText: Color(0xFF6B6558),
        positiveText: Color(0xFF6CC070),
        positiveBg: Color(0x1A6CC070),
        warningBg: Color(0x26E8A838),
        warningText: Color(0xFFE8A838),
        chipBg: Color(0x14FFFFFF),
        chipBorder: Color(0xFFE8A838),
      );
    }
    return const _GuideColors._(
      cardStart: Color(0xFFFFF3D0),
      cardEnd: Color(0xFFFFE8A0),
      cardShadow: Color(0x33D4A017),
      surface: Color(0x99FFFFFF),
      surfaceSelected: Color(0xFFFFD966),
      accent: Color(0xFFD4A017),
      accentDeep: Color(0xFFB8860B),
      titleText: Color(0xFF3A2C00),
      bodyText: Color(0xFF7A6000),
      mutedText: Color(0xFF9A7800),
      positiveText: Color(0xFF4A9A4A),
      positiveBg: Color(0xFFE8F5E8),
      warningBg: Color(0xFFFFF0E0),
      warningText: Color(0xFFB05000),
      chipBg: Color(0x8CFFFFFF),
      chipBorder: Color(0xFFD4A017),
    );
  }
}

// ─────────────────────────────────────────────
// Main page — wide ≥ 600 → two-column layout
// ─────────────────────────────────────────────

class PlusGuidePage extends ConsumerStatefulWidget {
  const PlusGuidePage({super.key});

  @override
  ConsumerState<PlusGuidePage> createState() => _PlusGuidePageState();
}

class _PlusGuidePageState extends ConsumerState<PlusGuidePage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _animateTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final formState = ref.watch(plusGuideFormProvider);
    final notifier = ref.read(plusGuideFormProvider.notifier);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= _kWideBreakpoint;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageController.hasClients &&
          _pageController.page?.round() != formState.currentStep) {
        _animateTo(formState.currentStep);
      }
    });

    final stepPages = [
      _Step0Confirm(lang: lang, notifier: notifier),
      _Step1Topic(lang: lang, formState: formState, notifier: notifier),
      _Step2Learn(lang: lang, formState: formState, notifier: notifier),
      _Step3Notify(lang: lang, formState: formState, notifier: notifier),
      _Step4Done(lang: lang, formState: formState, notifier: notifier),
    ];

    final indicator = _StepIndicator(currentStep: formState.currentStep, lang: lang);

    if (isWide) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: _VerticalStepIndicator(
                  currentStep: formState.currentStep,
                  lang: lang,
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: stepPages,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            indicator,
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: stepPages,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Step indicator — horizontal (phone)
// ─────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep, required this.lang});
  final int currentStep;
  final AppLanguage lang;

  static const _stepKeys = [
    'plus_guide_step_confirm',
    'plus_guide_step_topic',
    'plus_guide_step_learn',
    'plus_guide_step_notify',
    'plus_guide_step_done',
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final width = MediaQuery.sizeOf(context).width;
    final showLabels = width >= 360;

    return Padding(
      padding: const EdgeInsets.fromLTRB(_kCardOuterH, 12, _kCardOuterH, 8),
      child: Row(
        children: List.generate(_stepKeys.length * 2 - 1, (i) {
          if (i.isOdd) {
            final step = i ~/ 2;
            final done = step < currentStep;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 2,
                decoration: BoxDecoration(
                  color: done
                      ? tokens.primary
                      : tokens.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          }
          final step = i ~/ 2;
          final isActive = step == currentStep;
          final isDone = step < currentStep;
          final size = showLabels
              ? (isActive ? 28.0 : 22.0)
              : (isActive ? 24.0 : 18.0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? tokens.primary
                      : isActive
                          ? tokens.primary
                          : tokens.primary.withValues(alpha: 0.15),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: tokens.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: isDone
                      ? Icon(Icons.check, size: showLabels ? 14 : 12,
                             color: tokens.textOnPrimary)
                      : Text(
                          '${step + 1}',
                          style: TextStyle(
                            fontSize: isActive
                                ? (showLabels ? 13 : 11)
                                : (showLabels ? 11 : 10),
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? tokens.textOnPrimary
                                : tokens.primary.withValues(alpha: 0.5),
                          ),
                        ),
                ),
              ),
              if (showLabels) ...[
                const SizedBox(height: 4),
                Text(
                  uiString(lang, _stepKeys[step]),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    color: isActive ? tokens.primary : tokens.textMuted,
                  ),
                ),
              ],
            ],
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Step indicator — vertical (tablet / wide)
// ─────────────────────────────────────────────

class _VerticalStepIndicator extends StatelessWidget {
  const _VerticalStepIndicator({required this.currentStep, required this.lang});
  final int currentStep;
  final AppLanguage lang;

  static const _stepKeys = _StepIndicator._stepKeys;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: List.generate(_stepKeys.length * 2 - 1, (i) {
          if (i.isOdd) {
            final step = i ~/ 2;
            final done = step < currentStep;
            return Container(
              width: 2,
              height: 28,
              decoration: BoxDecoration(
                color: done
                    ? tokens.primary
                    : tokens.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }
          final step = i ~/ 2;
          final isActive = step == currentStep;
          final isDone = step < currentStep;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isActive ? 28 : 22,
                height: isActive ? 28 : 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? tokens.primary
                      : isActive
                          ? tokens.primary
                          : tokens.primary.withValues(alpha: 0.15),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: tokens.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: isDone
                      ? Icon(Icons.check, size: 14, color: tokens.textOnPrimary)
                      : Text(
                          '${step + 1}',
                          style: TextStyle(
                            fontSize: isActive ? 13 : 11,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? tokens.textOnPrimary
                                : tokens.primary.withValues(alpha: 0.5),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  uiString(lang, _stepKeys[step]),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    color: isActive ? tokens.primary : tokens.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared card shell — theme-aware
// ─────────────────────────────────────────────

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final c = _GuideColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _kCardOuterH, _kCardOuterV, _kCardOuterH, _kCardOuterBottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kCardMaxWidth),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.cardStart, c.cardEnd],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: c.cardShadow, blurRadius: 24, offset: const Offset(0, 8)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SingleChildScrollView(
                padding: padding ?? const EdgeInsets.all(_kCardInnerPadding),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Step 0: Confirm Start
// ─────────────────────────────────────────────

class _Step0Confirm extends StatelessWidget {
  const _Step0Confirm({required this.lang, required this.notifier});
  final AppLanguage lang;
  final PlusGuideNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final c = _GuideColors.of(context);
    final tt = Theme.of(context).textTheme;
    return _GuideCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surfaceSelected,
              ),
              child: const Center(
                child: Text('✨', style: TextStyle(fontSize: 38)),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            uiString(lang, 'plus_guide_welcome_title'),
            style: tt.titleLarge?.copyWith(
              color: c.titleText,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            uiString(lang, 'plus_guide_welcome_body'),
            style: tt.bodyMedium?.copyWith(
              color: c.bodyText,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _PrimaryBtn(
            label: uiString(lang, 'plus_guide_start_btn'),
            onTap: notifier.nextStep,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Step 1: Select Segment → Topic → Product
// ─────────────────────────────────────────────

class _Step1Topic extends ConsumerWidget {
  const _Step1Topic({
    required this.lang,
    required this.formState,
    required this.notifier,
  });
  final AppLanguage lang;
  final PlusGuideFormState formState;
  final PlusGuideNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segmentsAsync = ref.watch(segmentsProvider);
    final topicsAsync = ref.watch(plusGuideTopicsProvider);

    return _GuideCard(
      padding: const EdgeInsets.all(_kCardInnerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(label: uiString(lang, 'plus_guide_segment_title')),
          const SizedBox(height: 10),
          segmentsAsync.when(
            loading: () =>
                _LoadingRow(message: uiString(lang, 'plus_guide_loading')),
            error: (e, _) => _ErrorText(e.toString()),
            data: (segs) {
              final visible = segs.where((s) => s.published).toList();
              if (visible.isEmpty) {
                return _EmptyHint(uiString(lang, 'plus_guide_no_segments'));
              }
              return Wrap(
                spacing: 8,
                runSpacing: 6,
                children: visible
                    .map((s) => _ChoiceChip(
                          label: s.displayTitle(lang),
                          selected: formState.selectedSegment?.id == s.id,
                          onTap: () => notifier.selectSegment(s),
                        ))
                    .toList(),
              );
            },
          ),

          if (formState.selectedSegment != null) ...[
            const SizedBox(height: _kSectionSpacing),
            _SectionLabel(label: uiString(lang, 'plus_guide_topic_title')),
            const SizedBox(height: 10),
            topicsAsync.when(
              loading: () =>
                  _LoadingRow(message: uiString(lang, 'plus_guide_loading')),
              error: (e, _) => _ErrorText(e.toString()),
              data: (topics) {
                final visible = topics.where((t) => t.published).toList();
                if (visible.isEmpty) {
                  return _EmptyHint(uiString(lang, 'plus_guide_no_topics'));
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: visible
                      .map((t) => _ChoiceChip(
                            label: t.displayTitle(lang),
                            selected: formState.selectedTopic?.id == t.id,
                            onTap: () => notifier.selectTopic(t),
                          ))
                      .toList(),
                );
              },
            ),
          ],

          if (formState.selectedTopic != null) ...[
            const SizedBox(height: _kSectionSpacing),
            _SectionLabel(label: uiString(lang, 'plus_guide_product_title')),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _kProductListMaxHeight),
              child: SingleChildScrollView(
                child: _ProductList(
                  topicId: formState.selectedTopic!.id,
                  selected: formState.selectedProduct,
                  lang: lang,
                  onSelect: notifier.selectProduct,
                ),
              ),
            ),
          ],

          const SizedBox(height: _kSectionSpacing),
          Row(
            children: [
              _SecondaryBtn(
                label: uiString(lang, 'plus_guide_back'),
                onTap: notifier.prevStep,
              ),
              const SizedBox(width: _kButtonSpacing),
              Expanded(
                child: _PrimaryBtn(
                  label: uiString(lang, 'plus_guide_next'),
                  onTap: formState.selectedProduct != null
                      ? notifier.nextStep
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ProductList extends ConsumerWidget {
  const _ProductList({
    required this.topicId,
    required this.selected,
    required this.lang,
    required this.onSelect,
  });

  final String topicId;
  final Product? selected;
  final AppLanguage lang;
  final ValueChanged<Product> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsByTopicProvider(topicId));
    return productsAsync.when(
      loading: () =>
          _LoadingRow(message: uiString(lang, 'plus_guide_loading')),
      error: (e, _) => _ErrorText(e.toString()),
      data: (products) {
        final visible = products.where((p) => p.published).toList();
        if (visible.isEmpty) {
          return _EmptyHint(uiString(lang, 'plus_guide_no_products'));
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: visible
              .map((p) => _ProductCard(
                    product: p,
                    selected: selected?.id == p.id,
                    lang: lang,
                    onTap: () => onSelect(p),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.selected,
    required this.lang,
    required this.onTap,
  });
  final Product product;
  final bool selected;
  final AppLanguage lang;
  final VoidCallback onTap;

  String _title() {
    if (lang == AppLanguage.zhTw &&
        product.titleZh != null &&
        product.titleZh!.isNotEmpty) {
      return product.titleZh!;
    }
    if (product.titleEn != null && product.titleEn!.isNotEmpty) {
      return product.titleEn!;
    }
    return product.title;
  }

  @override
  Widget build(BuildContext context) {
    final c = _GuideColors.of(context);
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? c.surfaceSelected : c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? c.accent : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [BoxShadow(color: c.cardShadow, blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title(),
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.titleText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product.creditsRequired > 0
                        ? uiString(lang, 'plus_guide_credits_label')
                            .replaceAll('{n}', '${product.creditsRequired}')
                        : uiString(lang, 'plus_guide_free_label'),
                    style: tt.bodySmall?.copyWith(
                      color: product.creditsRequired > 0
                          ? c.mutedText
                          : c.positiveText,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.visibility_outlined, size: 20),
              color: c.mutedText,
              tooltip: uiString(lang, 'plus_guide_preview_btn'),
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) {
                    return _ProductPreviewSheet(product: product);
                  },
                );
              },
            ),
            if (selected)
              Icon(Icons.check_circle, color: c.accent, size: 22),
          ],
        ),
      ),
    );
  }
}

class _ProductPreviewSheet extends ConsumerWidget {
  const _ProductPreviewSheet({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final c = _GuideColors.of(context);
    final tokens = context.tokens;
    final previewItemsAsync = ref.watch(previewItemsProvider(product.id));

    final productTitleText = productTitle(product, lang);

    return FractionallySizedBox(
      heightFactor: 0.75,
      child: Container(
        decoration: BoxDecoration(
          color: c.cardStart,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: c.cardShadow,
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      productTitleText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: c.titleText,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: c.mutedText,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.coverImageUrl != null &&
                        product.coverImageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: AspectRatio(
                          aspectRatio: 3 / 2,
                          child: Image.network(
                            product.coverImageUrl!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    if ((product.contentArchitecture ?? '').isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        uiString(lang, 'plus_guide_content_arch'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.titleText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          productContentArchitecture(product, lang),
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: c.bodyText,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      uiString(lang, 'plus_guide_preview_items'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.titleText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child: previewItemsAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (e, _) => Center(
                          child: Text(
                            '$e',
                            style: TextStyle(color: tokens.textSecondary),
                          ),
                        ),
                        data: (items) {
                          if (items.isEmpty) {
                            return Center(
                              child: Text(
                                uiString(lang, 'plus_guide_no_preview_items'),
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                ),
                              ),
                            );
                          }
                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (_, index) {
                              final it = items[index];
                              return SizedBox(
                                width: 260,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: c.surface,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contentItemAnchor(it, lang),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: c.titleText,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Expanded(
                                        child: Text(
                                          contentItemText(it, lang),
                                          maxLines: 5,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.4,
                                            color: c.bodyText,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${it.displayIntent(lang)} · d${it.difficulty}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: c.mutedText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Step 2: Start Learning (credits / free)
// ─────────────────────────────────────────────

class _Step2Learn extends ConsumerStatefulWidget {
  const _Step2Learn({
    required this.lang,
    required this.formState,
    required this.notifier,
  });
  final AppLanguage lang;
  final PlusGuideFormState formState;
  final PlusGuideNotifier notifier;

  @override
  ConsumerState<_Step2Learn> createState() => _Step2LearnState();
}

class _Step2LearnState extends ConsumerState<_Step2Learn> {
  bool _adding = false;
  String? _error;

  Future<void> _doAdd() async {
    final product = widget.formState.selectedProduct;
    if (product == null) return;

    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _adding = true;
      _error = null;
    });

    try {
      final creditsRequired = product.creditsRequired;
      final libraryRepo = ref.read(libraryRepoProvider);
      final isFullAccess = ref.read(isFullAccessUserProvider);

      if (creditsRequired == 0 || isFullAccess) {
        await libraryRepo.ensureLibraryProductExists(
          uid: uid,
          productId: product.id,
        );
      } else {
        await ref.read(creditsRepoProvider).redeemCredits(
          uid: uid,
          productId: product.id,
          amount: creditsRequired,
        );
      }
      if (mounted) widget.notifier.nextStep();
    } catch (e) {
      if (mounted) {
        setState(() => _error = uiString(widget.lang, 'plus_guide_error_retry'));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final c = _GuideColors.of(context);
    final tt = Theme.of(context).textTheme;
    final product = widget.formState.selectedProduct;
    if (product == null) {
      return const _GuideCard(child: Center(child: CircularProgressIndicator()));
    }

    final user = ref.watch(authStateProvider).valueOrNull;
    final creditsAsync = ref.watch(creditsBalanceProvider);
    final libraryAsync = ref.watch(_safeLibraryProductsProvider);

    final bool isLoggedIn = user != null && !user.isAnonymous;
    final int balance = creditsAsync.valueOrNull ?? 0;
    final bool inLibrary = libraryAsync.valueOrNull
            ?.any((lp) => lp.productId == product.id) ??
        false;
    final bool isFree = product.creditsRequired == 0;
    final bool canAfford = balance >= product.creditsRequired;
    final bool isFullAccess = ref.watch(isFullAccessUserProvider);

    String productTitle = product.title;
    if (lang == AppLanguage.zhTw &&
        product.titleZh != null &&
        product.titleZh!.isNotEmpty) {
      productTitle = product.titleZh!;
    } else if (product.titleEn != null && product.titleEn!.isNotEmpty) {
      productTitle = product.titleEn!;
    }

    return _GuideCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            uiString(lang, 'plus_guide_step_learn'),
            style: tt.titleMedium?.copyWith(
              color: c.titleText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.book, color: c.accent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    productTitle,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.titleText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (!isLoggedIn) ...[
            _InfoBox(
              icon: Icons.person_outline,
              message: uiString(lang, 'plus_guide_login_required'),
            ),
            const SizedBox(height: 16),
            _PrimaryBtn(
              label: uiString(lang, 'plus_guide_login_btn'),
              onTap: () {
                final container = ProviderScope.containerOf(context);
                container.read(bottomTabIndexProvider.notifier).state = 3;
              },
            ),
          ] else if (inLibrary) ...[
            _InfoBox(
              icon: Icons.check_circle_outline,
              message: uiString(lang, 'plus_guide_in_library'),
              positive: true,
            ),
            const SizedBox(height: 16),
            _PrimaryBtn(
              label: uiString(lang, 'plus_guide_in_library_next'),
              onTap: widget.notifier.nextStep,
            ),
          ] else if (isFree || isFullAccess) ...[
            _InfoBox(
              icon: Icons.card_giftcard,
              message: uiString(lang, 'plus_guide_free_add'),
              positive: true,
            ),
            const SizedBox(height: 16),
            _PrimaryBtn(
              label: _adding
                  ? uiString(lang, 'plus_guide_adding')
                  : uiString(lang, 'plus_guide_free_add'),
              onTap: _adding ? null : _doAdd,
            ),
          ] else ...[
            Text(
              uiString(lang, 'plus_guide_credits_balance')
                  .replaceAll('{n}', '$balance'),
              style: tt.bodySmall?.copyWith(color: c.mutedText),
            ),
            const SizedBox(height: 12),
            if (canAfford) ...[
              _PrimaryBtn(
                label: _adding
                    ? uiString(lang, 'plus_guide_adding')
                    : uiString(lang, 'plus_guide_redeem_credits')
                        .replaceAll('{n}', '${product.creditsRequired}'),
                onTap: _adding ? null : _doAdd,
              ),
            ] else ...[
              _InfoBox(
                icon: Icons.warning_amber,
                message: uiString(lang, 'plus_guide_insufficient')
                    .replaceAll('{n}', '$balance'),
              ),
              const SizedBox(height: 12),
              _PrimaryBtn(
                label: uiString(lang, 'plus_guide_buy_btn'),
                onTap: () {
                  final container = ProviderScope.containerOf(context);
                  container.read(bottomTabIndexProvider.notifier).state = 3;
                },
              ),
            ],
          ],

          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorText(_error!),
          ],

          const SizedBox(height: 24),
          _SecondaryBtn(
            label: uiString(lang, 'plus_guide_back'),
            onTap: widget.notifier.prevStep,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Reactively watches library: re-subscribes when auth changes (login/logout).
final _safeLibraryProductsProvider =
    StreamProvider<List<UserLibraryProduct>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || user.isAnonymous) {
    return Stream.value(const <UserLibraryProduct>[]);
  }
  return ref.read(libraryRepoProvider).watchLibrary(user.uid);
});

// ─────────────────────────────────────────────
// Step 3: Set Notification
// ─────────────────────────────────────────────

class _Step3Notify extends ConsumerStatefulWidget {
  const _Step3Notify({
    required this.lang,
    required this.formState,
    required this.notifier,
  });
  final AppLanguage lang;
  final PlusGuideFormState formState;
  final PlusGuideNotifier notifier;

  @override
  ConsumerState<_Step3Notify> createState() => _Step3NotifyState();
}

class _Step3NotifyState extends ConsumerState<_Step3Notify> {
  bool _saving = false;
  String? _error;

  Future<void> _saveAndNext() async {
    final product = widget.formState.selectedProduct;
    if (product == null) return;

    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) {
      widget.notifier.nextStep();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await NotificationService().requestPermissionOnly();

      final config = PushConfig.defaults().copyWith(
        presetSlots: widget.formState.presetSlots,
        freqPerDay: widget.formState.freqPerDay,
      );

      final libraryRepo = ref.read(libraryRepoProvider);
      await libraryRepo.setPushEnabled(uid, product.id, true);
      await libraryRepo.setPushConfig(uid, product.id, config.toMap());
      await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);

      if (mounted) widget.notifier.nextStep();
    } catch (e) {
      if (mounted) {
        setState(() => _error = uiString(widget.lang, 'plus_guide_error_retry'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final c = _GuideColors.of(context);
    final tt = Theme.of(context).textTheme;
    final slots = widget.formState.presetSlots;
    final freq = widget.formState.freqPerDay;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final chipH = screenWidth < 360 ? 10.0 : 14.0;
    final chipV = screenWidth < 360 ? 6.0 : 8.0;
    final chipFont = screenWidth < 360 ? 11.0 : 13.0;

    return _GuideCard(
      padding: const EdgeInsets.all(_kCardInnerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            uiString(lang, 'plus_guide_notify_title'),
            style: tt.titleMedium?.copyWith(
              color: c.titleText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            uiString(lang, 'plus_guide_notify_body'),
            style: tt.bodySmall?.copyWith(color: c.bodyText, height: 1.5),
          ),
          const SizedBox(height: _kSectionSpacing),

          Text(
            uiString(lang, 'plus_guide_slots_label'),
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: c.titleText,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kAllSlots.map((slot) {
              final sel = slots.contains(slot);
              return GestureDetector(
                onTap: () {
                  final current = List<String>.from(slots);
                  if (sel) {
                    if (current.length > 1) current.remove(slot);
                  } else {
                    current.add(slot);
                  }
                  widget.notifier.setPresetSlots(current);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(horizontal: chipH, vertical: chipV),
                  decoration: BoxDecoration(
                    color: sel ? c.surfaceSelected : c.chipBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: sel ? c.chipBorder : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: sel
                        ? [BoxShadow(color: c.cardShadow, blurRadius: 6, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Text(
                    _kSlotLabels[slot] ?? slot,
                    style: TextStyle(
                      fontSize: chipFont,
                      fontWeight: FontWeight.w600,
                      color: sel ? c.accentDeep : c.mutedText,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: _kSectionSpacing),
          Text(
            uiString(lang, 'plus_guide_freq_label').replaceAll('{n}', '$freq'),
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: c.titleText,
            ),
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: c.accent,
              thumbColor: c.accent,
              inactiveTrackColor: c.accent.withValues(alpha: 0.2),
              overlayColor: c.accent.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: freq.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              onChanged: (v) => widget.notifier.setFreqPerDay(v.round()),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            _ErrorText(_error!),
          ],

          const SizedBox(height: _kSectionSpacing),
          _PrimaryBtn(
            label: _saving
                ? uiString(lang, 'plus_guide_saving')
                : uiString(lang, 'plus_guide_next'),
            onTap: _saving ? null : _saveAndNext,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.notifier.nextStep,
            child: Text(
              uiString(lang, 'plus_guide_skip_notify'),
              style: TextStyle(color: c.mutedText),
            ),
          ),
          _SecondaryBtn(
            label: uiString(lang, 'plus_guide_back'),
            onTap: widget.notifier.prevStep,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Step 4: Done
// ─────────────────────────────────────────────

class _Step4Done extends ConsumerWidget {
  const _Step4Done({
    required this.lang,
    required this.formState,
    required this.notifier,
  });
  final AppLanguage lang;
  final PlusGuideFormState formState;
  final PlusGuideNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = _GuideColors.of(context);
    final tt = Theme.of(context).textTheme;
    final product = formState.selectedProduct;
    String productTitle = product?.title ?? '';
    if (product != null) {
      if (lang == AppLanguage.zhTw &&
          product.titleZh != null &&
          product.titleZh!.isNotEmpty) {
        productTitle = product.titleZh!;
      } else if (product.titleEn != null && product.titleEn!.isNotEmpty) {
        productTitle = product.titleEn!;
      }
    }

    return _GuideCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Center(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              tween: Tween(begin: 0.5, end: 1.0),
              curve: Curves.elasticOut,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.surfaceSelected,
                ),
                child: const Center(
                  child: Text('🎉', style: TextStyle(fontSize: 44)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            uiString(lang, 'plus_guide_done_title'),
            style: tt.titleLarge?.copyWith(
              color: c.titleText,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            uiString(lang, 'plus_guide_done_body'),
            style: tt.bodyMedium?.copyWith(
              color: c.bodyText,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          if (productTitle.isNotEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${uiString(lang, "plus_guide_done_product")}$productTitle',
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.titleText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
          _PrimaryBtn(
            label: uiString(lang, 'plus_guide_finish'),
            onTap: () {
              notifier.reset();
              final container = ProviderScope.containerOf(context);
              container.read(bottomTabIndexProvider.notifier).state = 3;
            },
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              notifier.reset();
              final container = ProviderScope.containerOf(context);
              container.read(bottomTabIndexProvider.notifier).state = 0;
            },
            child: Text(
              uiString(lang, 'plus_guide_close'),
              style: TextStyle(color: c.mutedText),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared small widgets — all theme-aware
// ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = _GuideColors.of(context);
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: c.mutedText,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = _GuideColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.surfaceSelected : c.chipBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? c.chipBorder : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: selected
              ? [BoxShadow(color: c.cardShadow, blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? c.accentDeep : c.mutedText,
          ),
        ),
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = _GuideColors.of(context);
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: disabled ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          constraints: const BoxConstraints(minHeight: _kButtonMinHeight),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: disabled
                ? null
                : LinearGradient(colors: [c.accent, c.accentDeep]),
            color: disabled ? c.accent : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryBtn extends StatelessWidget {
  const _SecondaryBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = _GuideColors.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: c.mutedText,
        side: BorderSide(color: c.accent, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size(64, _kButtonMinHeight),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.message,
    this.positive = false,
  });
  final IconData icon;
  final String message;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final c = _GuideColors.of(context);
    final color = positive ? c.positiveText : c.warningText;
    final bg = positive ? c.positiveBg : c.warningBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow({this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    final c = _GuideColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
          ),
          const SizedBox(width: 10),
          Text(
            message ?? '…',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.mutedText),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = _GuideColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.mutedText),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = _GuideColors.of(context);
    return Text(
      message,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.warningText),
    );
  }
}
