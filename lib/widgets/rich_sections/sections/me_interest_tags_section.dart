import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_spacing.dart';
import '../../../theme/app_tokens.dart';
import '../../../bubble_library/providers/providers.dart';
import '../../../localization/app_language.dart';
import '../../../localization/app_language_provider.dart';
import '../../../localization/app_strings.dart';
import '../user/me_prefs_store.dart';
import '../learning_metrics_providers.dart';

class MeInterestTagsSection extends ConsumerStatefulWidget {
  const MeInterestTagsSection({super.key});

  @override
  ConsumerState<MeInterestTagsSection> createState() =>
      _MeInterestTagsSectionState();
}

class _MeInterestTagsSectionState extends ConsumerState<MeInterestTagsSection> {
  static const _localKey = 'local';
  List<String> _tags = [];
  List<String> _custom = [];
  bool _loading = true;

  String _uidOrLocal() {
    try {
      return ref.read(uidProvider);
    } catch (_) {
      return _localKey;
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final key = _uidOrLocal();
    final tags = await MePrefsStore.getInterestTags(key);
    final custom = await MePrefsStore.getCustomTags(key);
    if (!mounted) return;
    setState(() {
      _tags = tags;
      _custom = custom;
      _loading = false;
    });
  }

  Future<void> _save(List<String> nextTags) async {
    final key = _uidOrLocal();
    await MePrefsStore.setInterestTags(key, nextTags);
    ref.invalidate(meInterestTagsProvider(key));
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final lang = ref.watch(appLanguageProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: tokens.cardBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(uiString(lang, 'interest_tags'),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: tokens.textPrimary)),
              const Spacer(),
              TextButton.icon(
                onPressed: _loading
                    ? null
                    : () async {
                        final next = await _openEditSheet(context, lang);
                        if (next != null) await _save(next);
                      },
                icon: Icon(Icons.edit, size: 18, color: tokens.primary),
                label: Text(uiString(lang, 'edit'),
                    style: TextStyle(color: tokens.primary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_tags.isEmpty)
            Text(uiString(lang, 'interest_tags_pick_hint'),
                style: TextStyle(
                    color: tokens.textSecondary, fontSize: _chipFontSize))
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: _tags.map((t) => _chip(context, lang, t)).toList(),
            ),
        ],
      ),
    );
  }

  String _displayTag(String raw, AppLanguage lang) {
    if (lang != AppLanguage.zhTw) return raw;
    switch (raw) {
      case 'AI':
        return 'AI';
      case 'Space':
        return '太空';
      case 'Aesthetics':
        return '美感';
      case 'Finance':
        return '理財';
      case 'Health':
        return '健康';
      case 'Psychology':
        return '心理學';
      case 'Parenting':
        return '親子';
      case 'Productivity':
        return '生產力';
      case 'Coding':
        return '程式';
      case 'Career':
        return '職涯';
      case 'Reading':
        return '閱讀';
      case 'Communication':
        return '溝通';
      case 'English':
        return '英文';
      case 'Writing':
        return '寫作';
      case 'Habits':
        return '習慣養成';
      case 'Meditation':
        return '冥想';
      case 'Nutrition':
        return '飲食營養';
      case 'Fitness':
        return '健身';
      case 'Design':
        return '設計';
      case 'Entrepreneurship':
        return '創業';
      default:
        return raw;
    }
  }

  static const _chipPadding = EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs);
  static const _chipFontSize = 13.0;

  Widget _chip(BuildContext context, AppLanguage lang, String text) {
    final tokens = context.tokens;
    return Container(
      padding: _chipPadding,
      decoration: BoxDecoration(
        gradient: tokens.chipGradient,
        color: tokens.chipGradient == null ? tokens.chipBg : null,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Text(_displayTag(text, lang),
          style: TextStyle(
              color: tokens.textPrimary,
              fontSize: _chipFontSize,
              fontWeight: FontWeight.w500)),
    );
  }

  Future<List<String>?> _openEditSheet(
      BuildContext context, AppLanguage lang) async {
    final tokens = context.tokens;
    final key = _uidOrLocal();

    // 內建 + 自訂
    final builtin = <String>[
      'AI',
      'Space',
      'Aesthetics',
      'Finance',
      'Health',
      'Psychology',
      'Parenting',
      'Productivity',
      'Coding',
      'Career',
      'Reading',
      'Communication',
      'English',
      'Writing',
      'Habits',
      'Meditation',
      'Nutrition',
      'Fitness',
      'Design',
      'Entrepreneurship',
    ];

    final all = {...builtin, ..._custom}.toList()..sort();
    final selected = {..._tags};
    final controller = TextEditingController();

    final sheetFuture = showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModal) {
            Widget selectableChip(String t) {
              final isSel = selected.contains(t);
              return _selectableChip(context, tokens, lang, t, isSel, () {
                setModal(() {
                  if (isSel) {
                    selected.remove(t);
                  } else {
                    selected.add(t);
                  }
                });
              });
            }

            return Container(
              margin: const EdgeInsets.all(AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: tokens.cardBg,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: tokens.cardBorder),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(uiString(lang, 'interest_tags_edit_title'),
                        style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16)),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: all.map(selectableChip).toList()),
                    const SizedBox(height: AppSpacing.sm),
                    Text(uiString(lang, 'interest_tags_add_custom'),
                        style: TextStyle(
                            color: tokens.textSecondary,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            style: TextStyle(color: tokens.textPrimary),
                            decoration: InputDecoration(
                              hintText:
                                  uiString(lang, 'interest_tags_hint_custom'),
                              hintStyle:
                                  TextStyle(color: tokens.textSecondary),
                              filled: true,
                              fillColor: tokens.chipBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                borderSide:
                                    BorderSide(color: tokens.cardBorder),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _appPrimaryButton(
                          tokens: tokens,
                          label: uiString(lang, 'interest_tags_add_btn'),
                          onPressed: () async {
                            final t = controller.text.trim();
                            if (t.isEmpty) return;
                            await MePrefsStore.addCustomTag(key, t);
                            controller.clear();
                            final fresh =
                                await MePrefsStore.getCustomTags(key);
                            setModal(() {
                              _custom = fresh;
                              all
                                ..clear()
                                ..addAll(
                                    {...builtin, ...fresh}.toList()..sort());
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _appOutlinedButton(
                            tokens: tokens,
                            label: uiString(lang, 'interest_tags_clear'),
                            onPressed: () =>
                                setModal(() => selected.clear()),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: _appPrimaryButton(
                            tokens: tokens,
                            label: uiString(lang, 'interest_tags_save'),
                            onPressed: () => Navigator.of(context)
                                .pop(selected.toList()..sort()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    sheetFuture.whenComplete(() => controller.dispose());
    return sheetFuture;
  }

  Widget _selectableChip(BuildContext context, AppTokens tokens,
      AppLanguage lang, String text, bool selected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: _chipPadding,
          decoration: BoxDecoration(
            gradient: selected ? null : tokens.chipGradient,
            color: selected
                ? tokens.primaryPale
                : (tokens.chipGradient == null ? tokens.chipBg : null),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? tokens.primary : tokens.cardBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(_displayTag(text, lang),
              style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: _chipFontSize,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _appPrimaryButton({
    required AppTokens tokens,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: tokens.primary,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: tokens.textOnPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
        ),
      ),
    );
  }

  Widget _appOutlinedButton({
    required AppTokens tokens,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
            border: Border.all(color: tokens.cardBorder),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
        ),
      ),
    );
  }
}
